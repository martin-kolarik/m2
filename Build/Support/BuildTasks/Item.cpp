using namespace System;
// using namespace System::Text;
using namespace System::IO;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

  public ref class Item : public Task {

    private:
      array<ITaskItem^>^ input;
      ITaskItem^ item;
      long index;

    public:
        [Output]
        property ITaskItem^ Output
        {
            ITaskItem^ get() {
                return item;
            }
        }

        [Required]
        property long Index
        {
            long get() {
                return index;
            }
            void set( long value ) {
                index = value;
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
            item = input[index];
            return true;
        }

    };
}


