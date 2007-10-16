using namespace System;
// using namespace System::Text;
using namespace System::IO;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class ShortenPath: public Task {

    private:
      array<ITaskItem^>^ input;
      array<ITaskItem^>^ result;

    public:
        [Output]
        property array<ITaskItem^>^ Shortened
        {
            array<ITaskItem^>^ get() {
                return result;
            }
            void set( array<ITaskItem^>^ value ) {
                result = value;
            }
        }

        [Required]
        property array<ITaskItem^>^ Input
        {
            array<ITaskItem^>^ get() {
                return input;
            }
            void set( array<ITaskItem^>^ value ) {
                input = value;
            }
        }

        virtual bool Execute() override {
            int i = 0;
            ITaskItem^ TI;
            result = gcnew array<ITaskItem^>( input->Length );

            input->CopyTo( result, 0 );
            for (;i<input->Length;i++) {
                TI = (ITaskItem^)result->GetValue( i );
                TI->ItemSpec = Path::GetFullPath( result->GetValue( i )->ToString() );
                result->SetValue( TI, i );
            }
            return true;
        }

    };
}


