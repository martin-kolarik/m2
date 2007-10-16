using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class WriteLinesToEncodedFile: public Task {

  private:
    ITaskItem^ file;
    array<ITaskItem^>^ lines;
    bool overwrite;
    IO::StreamWriter^ streamWriter;
    Text::Encoding^ encoding;
  
  public:

    [Required]
    property ITaskItem^ File {
      ITaskItem^ get() {
        return file;
      }
      void set( ITaskItem^ value ) {
        file = value;       
      }
    }

    property array<ITaskItem^>^ Lines {
      array<ITaskItem^>^ get() {
        return lines;
      }       
      void set( array<ITaskItem^>^ value ) {
        lines = value;       
      }       
    }

    property bool Overwrite {
      bool get() {
        return overwrite;
      }       
      void set( bool value ) {
        overwrite = value;       
      }
    }
    
    [Required]
    property int Encoding {
      int get() {
        return encoding->CodePage;
      }       
      void set( int value ) {
        encoding = Text::UnicodeEncoding::GetEncoding( value );
      }
    }

    virtual bool Execute() override {
      int i = 0;
    
      if (file == nullptr) {
        throw gcnew ArgumentNullException ("file", "File TaskItem must be set.");
      }
      if (file->ItemSpec == "") {
        throw gcnew ArgumentException ("File must be specified in ItemSpec.");
      }
      try {
        streamWriter = gcnew IO::StreamWriter (file->GetMetadata ("FullPath"), !overwrite, encoding);
        for (;i<lines->Length;i++) {
          streamWriter->WriteLine(lines->GetValue(i));
        }
        return true;
      } catch (Exception^ ex) {
        Log->LogErrorFromException (ex);
        return false;
      } finally {
        if (streamWriter != nullptr) {
          streamWriter->Close();
        }
      }
    }

  }; // CLASS
  
}