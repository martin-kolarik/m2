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
      long minimumIndex;
      long maximum;
      long maximumIndex;

    public:
        [Output]
        property long Minimum
        {
            long get() {
                return minimum;
            }
        }

        [Output]
        property long MinimumIndex
        {
            long get() {
                return minimumIndex;
            }
        }

        [Output]
        property long Maximum
        {
            long get() {
                return maximum;
            }
        }

        [Output]
        property long MaximumIndex
        {
            long get() {
                return maximumIndex;
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

        virtual bool Execute() override
        {
            long min = Int32::MaxValue;
            minimumIndex = -1;
            long max = Int32::MinValue;
            maximumIndex = -1;

            for (int i = 0; i < input->Length; i++ ) {
                try {
                    long current = Int32::Parse( input->GetValue( i )->ToString());
                    if( current > max ) {
                        max = current;
                        maximumIndex = i;
                    }
                    if( current < min ) {
                        min = current;
                        minimumIndex = i;
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


