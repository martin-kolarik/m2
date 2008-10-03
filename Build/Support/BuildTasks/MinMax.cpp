using namespace System;
// using namespace System::Text;
using namespace System::IO;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class MinMax: public Task {

    private:
      array<ITaskItem^>^ input;
      long minimum;
      long maximum;

    public:
        [Output]
        property long Minimum
        {
            long get() {
                return minimum;
            }
            void set( long value ) {
                minimum = value;
            }
        }

        [Output]
        property long Maximum
        {
            long get() {
                return maximum;
            }
            void set( long value ) {
                maximum = value;
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
            long min = Int32::MaxValue;
            long max = Int32::MinValue;

            for (int i = 0; i < input->Length; i++ ) {
                try {
                    long current = Int32::Parse( input->GetValue( i )->ToString());
                    if( current > max ) {
                        max = current;
                    }
                    if( current < min ) {
                        min = current;
                    }
                } catch( Exception^ ) {
                    // ignore
                }
            }

            minimum = min;
            maximum = max;

            return true;
        }

    };
}


