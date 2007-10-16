using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class BuildNumber: public Task {

  private:
    String^ file;
    bool preservevalue;
    int value;
  
  public:

    [Required]
    property String^ File {
      String^ get() {
        return file;
      }
      void set( String^ value ) {
        file = value;
      }
    }

    property bool PreserveValue {
      bool get() {
        return preservevalue;
      }       
      void set( bool value ) {
        preservevalue = value;       
      }
    }
    
    [Output]
    property int Value {
      int get() {
        return value;
      }       
    }

    virtual bool Execute() override {
      IO::StreamReader^ streamReader;
      IO::StreamWriter^ streamWriter;
      String^ line;
    
      try {
        if (IO::File::Exists( file )) {
          streamReader = gcnew IO::StreamReader( file );
          line = streamReader->ReadLine();
          if (line != nullptr) {
            value = Int32::Parse( line );
          }
          streamReader->Close();
          streamReader = nullptr;
        }
        if (!preservevalue) {
          value++;
          streamWriter = gcnew IO::StreamWriter( file );
          streamWriter->WriteLine( value.ToString());
        }
        return true;

      } catch (Exception^ ex) {
        Log->LogErrorFromException (ex);
        return false;

      } finally {
        if (streamReader != nullptr) {
          streamReader->Close();
        }
        if (streamWriter != nullptr) {
          streamWriter->Close();
        }
      }
    }

  }; // CLASS
  
}