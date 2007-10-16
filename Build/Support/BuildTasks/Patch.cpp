using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class Patch: public Task {

  private:
    String^ propertyvalue;
    wchar_t patchlead;
    array<ITaskItem^>^ keys;
    array<ITaskItem^>^ values;
  
  public:
    [Required]
    [Output]
    property String^ Value {
      String^ get() {
        return propertyvalue;
      }
      void set( String^ value ) {
        propertyvalue = value;
      }
    }

    [Required]
    property array<ITaskItem^>^ Keys {
      array<ITaskItem^>^ get() {
        return keys;
      }
      void set( array<ITaskItem^>^ value ) {
        keys = value;
      }
    }

    [Required]
    property array<ITaskItem^>^ Patches {
      array<ITaskItem^>^ get() {
        return values;
      }
      void set( array<ITaskItem^>^ value ) {
        values = value;
      }
    }

    virtual bool Execute() override {
      int i = 0;
      for (;i<keys->Length;i++) {
        propertyvalue = propertyvalue->Replace( "#(" + keys->GetValue(i) + ")", values->GetValue(i)->ToString() );
      }
      return true;
    }

  }; // CLASS
  
}