defmodule SpikeTest do
  use ExUnit.Case

  describe "Spike.Struct.new/1" do
    test "initializes simple form struct from params" do
      form =
        Test.SimpleForm.new(%{
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
        Test.SimpleForm.new(%{
          first_name: "Spike",
          last_name: "Spiegel",
          age: "36",
          email: "spike@example.com",
          accepts_conditions: "true"
        })

      assert form.ref != nil
    end

    test "initializes nested struct" do
      form =
        Test.ComplexForm.new(%{
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
        Test.ComplexForm.new(%{
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
    test "validates nested struct" do
      form = Test.ComplexForm.new(%{})

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{
                 company: [presence: "must be present"],
                 accepts_conditions: [acceptance: "must be accepted"]
               }
             }

      form = Test.ComplexForm.new(%{company: %{}})

      refute Spike.valid?(form)

      assert Spike.errors(form) == %{
               form.ref => %{accepts_conditions: [acceptance: "must be accepted"]},
               form.company.ref => %{name: [presence: "must be present"]}
             }

      assert Spike.errors(form)[form.ref] == %{
               accepts_conditions: [acceptance: "must be accepted"]
             }
    end

    test "allows validations" do
      form =
        Test.SimpleForm.new(%{
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
  end

  describe "Spike.update/2" do
    test "updates the structs and casts data" do
      form =
        Test.ComplexForm.new(%{
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
        |> Spike.update(hubert_ref, %{name: "Umberto"})
        |> Spike.update(form_ref, %{accepts_conditions: "false"})

      assert form.accepts_conditions == false
      assert (form.partners |> hd()).name == "Umberto"
      assert form.ref == form_ref
      assert hubert_ref == hd(form.partners).ref
    end

    test "updates the structs and changes validation" do
      form =
        Test.ComplexForm.new(%{
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
    test "deletes the struct by ref" do
      form =
        Test.ComplexForm.new(%{
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
    test "appends the newly initialized struct at the end of the embeds_many list" do
      form =
        Test.ComplexForm.new(%{
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
end
