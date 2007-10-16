using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class EvaluateProductProperty: public Task {

  private:
     String^ _PropertyName;
     String^ _DefaultValue;
     String^ _PropertyValue;
  
  public:

    [Required]
    property String^ PropertyName {
      String^ get() {
        return _PropertyName;
      }
      void set( String^ value ) {
        _PropertyName = value;
      }
    }
  
    [Required]
    property String^ DefaultValue {
      String^ get() {
        return _DefaultValue;
      }
      void set( String^ value ) {
        _DefaultValue = value;
      }
    }
  
    [Output]
    property String^ PropertyValue {
      String^ get() {
        return _PropertyValue;
      }
    }
  
    virtual bool Execute() override {
      String^ Value; // CurrentValue
      Project^ CP;
    
      if (_PropertyName == nullptr) {
        return false;
      }
      CP = ((Engine^)BuildEngine)->GetLoadedProject( BuildEngine->ProjectFileOfTaskNode );

      Value = CP->GetEvaluatedProperty( "MSBuildProjectName" ) + "." + _PropertyName;
      if (Value != nullptr) {
        _PropertyValue = Value;
        return true;
      }
      
      Value = CP->GetEvaluatedProperty( _PropertyName );
      if (Value != nullptr) {
        _PropertyValue = Value;
        return true;
      }

      _PropertyValue = _DefaultValue;
      return true;
    }

  };
  
}