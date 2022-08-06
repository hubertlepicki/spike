defmodule SpikeTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Spike.FormDataData.new/1" do
    test "initializes simple form form_data from params" do
      form =
        Test.SimpleFormData.new(%{
          first_name: "Spike",
          last_name: "Spiegel",
          age: "36",
          email: "spike@example.com",
          accepts_conditions: "true"
        })

      assert form.first_name == "Spike"
      assert form.last_name == "Spiegel"
      assert form.age == 36
      assert form.email == "spike@example.com"
      assert form.accepts_conditions == true
    end

    test "autogenerates ref field" do
      form =
        Test.SimpleFormData.new(%{
          first_name: "Spike",
          last_name: "Spiegel",
          age: "36",
          email: "spike@example.com",
          accepts_conditions: "true"
        })

      assert form.ref != nil
    end

    test "initializes nested form_data" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      assert form.accepts_conditions == true
      assert form.company.name == "AmberBit"
      assert form.company.country == "Poland"
      [p1, p2] = form.partners

      assert p1.name == "Hubert"
      assert p2.name == "Wojciech"
    end

    test "sets embeds_many fields to [] by default" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          accepts_conditions: "true"
        })

      assert form.partners == []
    end

    test "casts types properly" do
      form =
        Test.TypeTestForm.new(%{
          name: "Hubert",
          # yeah right
          age: "30",
          accepts_conditions: "1",
          dob: "1992-01-01",
          inserted_at: "1992-01-01 00:00:00"
        })

      assert form.name == "Hubert"
      assert form.age == 30
      assert form.accepts_conditions == true
      assert form.dob == ~D[1992-01-01]
    end
  end

  describe "private fields" do
    test "should be able to set private fields on new/2 if cast_private: true" do
      ref = Spike.UUID.generate()

      form =
        Test.PrivateForm.new(
          %{
            ref: ref,
            public_field: "hello",
            private_field: "world",
            subform: %{public_field: "hola", private_field: "el mundo"}
          },
          cast_private: true
        )

      assert form.public_field == "hello"
      assert form.private_field == "world"
      assert form.ref == ref
      assert form.subform.public_field == "hola"
      assert form.subform.private_field == "el mundo"
    end

    test "should not be able to set private fields on new/2 if cast_private: false" do
      ref = Spike.UUID.generate()

      form =
        Test.PrivateForm.new(%{
          ref: ref,
          public_field: "hello",
          private_field: "world",
          subform: %{public_field: "hola", private_field: "el mundo"}
        })

      assert form.public_field == "hello"
      assert form.private_field == nil
      assert form.ref != ref
      assert form.subform.public_field == "hola"
      assert form.subform.private_field == nil
    end

    test "should not be able to update private fields, unless set_private is called" do
      form =
        Test.PrivateForm.new(%{
          public_field: "hello",
          subform: %{public_field: "hola"}
        })

      form =
        Spike.update(form, form.ref, %{public_field: "upd1", private_field: "upd2", ref: "upd3"})

      form =
        Spike.update(form, form.subform.ref, %{public_field: "Hola", private_field: "el mundo"})

      assert form.public_field == "upd1"
      assert form.private_field == nil
      assert form.subform.public_field == "Hola"
      assert form.subform.private_field == nil

      form = Spike.set_private(form, form.ref, :private_field, "upd2")
      form = Spike.set_private(form, form.ref, :ref, "elo")

      form = Spike.set_private(form, form.subform.ref, :private_field, "el mundo")

      assert form.private_field == "upd2"
      assert form.ref == "elo"
      assert form.subform.private_field == "el mundo"
    end
  end

  describe "Spike.valid?/1 && Spike.errors/1 && Spike.has_errors?/3 && Spike.has_errors?/4 && Spike.human_readable_errors/1" do
    test "allows validations" do
      form =
        Test.SimpleFormData.new(%{
          last_name: "Spiegel",
          accepts_conditions: "false"
        })

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{
                 accepts_conditions: [acceptance: "must be accepted"],
                 first_name: [presence: "must be present"]
               }
             }

      assert Spike.human_readable_errors(form) == %{
               "accepts_conditions" => ["must be accepted"],
               "first_name" => ["must be present"]
             }

      assert Spike.has_errors?(form, form.ref, :first_name)
      assert Spike.has_errors?(form, form.ref, :first_name, "must be present")
      refute Spike.has_errors?(form, form.ref, :last_name)
      refute Spike.has_errors?(form, form.ref, :last_name, "must be present")
    end

    test "validates nested form_data" do
      form = Test.ComplexFormData.new(%{})

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{
                 company: [presence: "must be present"],
                 accepts_conditions: [acceptance: "must be accepted"]
               }
             }

      assert Spike.human_readable_errors(form) == %{
               "company" => ["must be present"],
               "accepts_conditions" => ["must be accepted"]
             }

      form = Test.ComplexFormData.new(%{company: %{}})

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{accepts_conditions: [acceptance: "must be accepted"]},
               form.company.ref => %{name: [presence: "must be present"]}
             }

      assert Spike.human_readable_errors(form) == %{
               "accepts_conditions" => ["must be accepted"],
               "company.name" => ["must be present"]
             }

      assert Spike.errors(form)[form.ref] == %{
               accepts_conditions: [acceptance: "must be accepted"]
             }
    end
  end

  describe "Spike.update/2" do
    test "updates the form_datas and casts data" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      hubert_ref = hd(form.partners).ref
      form_ref = form.ref

      form =
        form
        |> Spike.update(hubert_ref, %{name: "Huberto"})
        |> Spike.update(hubert_ref, %{name: "Umberto"})
        |> Spike.update(form_ref, %{accepts_conditions: "false"})

      assert form.accepts_conditions == false
      assert (form.partners |> hd()).name == "Umberto"
      assert form.ref == form_ref
      assert hubert_ref == hd(form.partners).ref
    end

    test "updates the embeds and casts data" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [],
          accepts_conditions: "true"
        })

      form_ref = form.ref

      form =
        form
        |> Spike.update(form_ref, %{partners: [%{name: "Hubert"}, %{name: "Wojciech"}]})

      assert (form.partners |> hd()).name == "Hubert"
      assert (form.partners |> Enum.reverse() |> hd()).name == "Wojciech"
      assert form.ref == form_ref
    end

    test "updates the embeds and preinitialized form data" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [],
          accepts_conditions: "true"
        })

      preinitialized = Test.ComplexFormData.PartnerFormData.new(%{name: "Hubert"})

      form_ref = form.ref

      form =
        form
        |> Spike.update(form_ref, %{
          partners: [preinitialized]
        })

      assert (form.partners |> hd()).name == "Hubert"
      assert form.partners |> hd() == preinitialized
      assert form.ref == form_ref
    end

    test "updates the form_datas and changes validation" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      form =
        form
        |> Spike.update(form.company.ref, %{name: ""})

      refute Spike.valid?(form)
      assert Spike.errors(form) == %{form.company.ref => %{name: [presence: "must be present"]}}
    end

    test "runs update callbacks on struct and all it's parents" do
      form =
        Test.ComplexFormDataWithCallbacks.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      hubert_ref = hd(form.partners).ref

      output =
        capture_io(fn ->
          Spike.update(form, hubert_ref, %{name: "Humberto"})
        end)

      assert output =~ "updated #{hubert_ref}, name changed from Hubert to Humberto"
      assert output =~ "updated #{form.ref}, changed partners"

      output =
        capture_io(fn ->
          Spike.update(form, form.company.ref, %{name: "AmberBitos"})
        end)

      assert output == ""
    end

    test "doesn't update the form or embeds if nothing changed" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      hubert_ref = hd(form.partners).ref
      form_ref = form.ref

      form =
        form
        |> Spike.update(hubert_ref, %{name: "Hubert"})
        |> Spike.update(form_ref, %{accepts_conditions: "true"})

      assert form.accepts_conditions == true
      assert (form.partners |> hd()).name == "Hubert"
      assert form.ref == form_ref
      assert hubert_ref == hd(form.partners).ref
    end
  end

  describe "Spike.delete/2" do
    test "deletes the form_data by ref" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      hubert_ref = hd(form.partners).ref
      company_ref = form.company.ref

      form =
        form
        |> Spike.delete(hubert_ref)

      assert hd(form.partners).name == "Wojciech"
      assert length(form.partners) == 1

      form =
        form
        |> Spike.delete(company_ref)

      assert form.company == nil

      form = form |> Spike.delete(form.ref)
      assert form == nil
    end
  end

  describe "Spike.append/2" do
    test "appends and initializes form_data at the end of the embeds_many list" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          accepts_conditions: "true"
        })

      form =
        form
        |> Spike.append(form.ref, :partners, %{name: "Hubert"})
        |> Spike.append(form.ref, :partners, %{name: "Wojciech"})

      assert hd(form.partners).name == "Hubert"
      assert hd(form.partners |> Enum.reverse()).name == "Wojciech"
    end

    test "appends already initialzied form data at the end of embeds_many list" do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          accepts_conditions: "true"
        })

      form =
        form
        |> Spike.append(
          form.ref,
          :partners,
          Test.ComplexFormData.PartnerFormData.new(%{name: "Hubert"})
        )
        |> Spike.append(
          form.ref,
          :partners,
          Test.ComplexFormData.PartnerFormData.new(%{name: "Wojciech"})
        )

      assert hd(form.partners).name == "Hubert"
      assert hd(form.partners |> Enum.reverse()).name == "Wojciech"
    end
  end

  describe "ditry tracking" do
    setup do
      form =
        Test.ComplexFormData.new(%{
          company: %{
            name: "AmberBit",
            country: "Poland"
          },
          partners: [
            %{name: "Hubert"},
            %{name: "Wojciech"}
          ],
          accepts_conditions: "true"
        })

      {:ok, form: form}
    end

    test "should be pristine initially", %{form: form} do
      assert Spike.dirty_fields(form) == %{}
    end

    test "should track the fields that were updated", %{form: form} = initial do
      form =
        form
        |> Spike.update(form.ref, %{accepts_conditions: "false"})

      assert Spike.dirty_fields(form) == %{form.ref => [:accepts_conditions]}

      form =
        form
        |> Spike.append(form.ref, :partners, %{name: "John"})

      assert Spike.dirty_fields(form) == %{form.ref => [:accepts_conditions, :partners]}

      hubert_ref = hd(form.partners).ref

      form =
        form
        |> Spike.update(hubert_ref, %{name: "Umberto"})

      assert Spike.dirty_fields(form) == %{
               form.ref => [:accepts_conditions, :partners],
               hubert_ref => [:name]
             }

      form =
        form
        |> Spike.delete(form.company.ref)

      assert Spike.dirty_fields(form) == %{
               form.ref => [:accepts_conditions, :company, :partners],
               hubert_ref => [:name]
             }

      form = initial.form |> Spike.make_dirty()

      assert Spike.dirty_fields(form) == %{
               form.company.ref => [:country, :name],
               form.ref => [:accepts_conditions, :company, :partners],
               hd(form.partners).ref => [:name],
               hd(form.partners |> Enum.reverse()).ref => [:name]
             }

      form = form |> Spike.make_pristine()

      assert Spike.dirty_fields(form) == %{}

      form = initial.form

      company_ref = form.company.ref

      form =
        form
        |> Spike.update(hubert_ref, %{name: "Umberto"})
        |> Spike.update(company_ref, %{name: "AmberBito"})

      assert Spike.dirty_fields(form) == %{
               form.ref => [:company, :partners],
               hubert_ref => [:name],
               company_ref => [:name]
             }
    end
  end
end
