defmodule SpikeTest do
  use ExUnit.Case

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
  end

  describe "Spike.valid?/1 & Spike.errors/1" do
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

      form = Test.ComplexFormData.new(%{company: %{}})

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{accepts_conditions: [acceptance: "must be accepted"]},
               form.company.ref => %{name: [presence: "must be present"]}
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
    test "appends the newly initialized form_data at the end of the embeds_many list" do
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
               form.ref => [:accepts_conditions, :partners, :company],
               hubert_ref => [:name]
             }

      form = initial.form |> Spike.make_dirty()

      assert Spike.dirty_fields(form) == %{
               form.company.ref => [:name, :country],
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
               form.ref => [:partners, :company],
               hubert_ref => [:name],
               company_ref => [:name]
             }
    end
  end

  describe "serialization" do
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

      {:ok, %{form: form}}
    end

    test "should convert the given form data to map of params", %{form: form} do
      assert Spike.to_params(form) == %{
               "company" => %{
                 "name" => "AmberBit",
                 "country" => "Poland"
               },
               "partners" => [
                 %{"name" => "Hubert"},
                 %{"name" => "Wojciech"}
               ],
               "accepts_conditions" => true
             }
    end

    test "should convert given form data to JSON", %{form: form} do
      assert Spike.to_json(form) ==
               "{\"accepts_conditions\":true,\"company\":{\"country\":\"Poland\",\"name\":\"AmberBit\"},\"partners\":[{\"name\":\"Hubert\"},{\"name\":\"Wojciech\"}]}"
    end
  end
end
