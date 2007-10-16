using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class EmptyItemGroup: public Task {

  public:

    [Output]
    property array<ITaskItem^>^ ItemGroup {
      array<ITaskItem^>^ get() {
        return gcnew array<ITaskItem^>(0);
      }       
      void set( array<ITaskItem^>^ Value ) {
      }       
    }

    virtual bool Execute() override {
      return true;
    }

  }; // CLASS
  
}