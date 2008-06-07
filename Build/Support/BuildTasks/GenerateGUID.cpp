using namespace System;
using namespace Microsoft::Build::Framework;
using namespace Microsoft::Build::Utilities;

namespace Tasks {

    public ref class GenerateGUID: public Task {

    private:
        String^ guid;

    public:

        [Output]
        property String^ GUID {

            String^ get() {
                return guid;
            }       

            void set( String^ Value ) {
                guid = Value;
            }       

        }

        virtual bool Execute() override {
            guid = System::Guid::NewGuid().ToString();
            return true;
        }

    }; // CLASS

}