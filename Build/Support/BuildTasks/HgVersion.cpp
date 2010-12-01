/*
Copyright © 2005 Paul Welter. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
*/

using namespace System;
using namespace System::Collections::Generic;
using namespace System::Diagnostics;
using namespace System::Text;
using namespace System::Text::RegularExpressions;
using namespace System::IO;
using namespace Microsoft::Build::Utilities;
using namespace Microsoft::Build::Framework;

namespace Tasks
{
    /// <summary>
    /// Summarize the revision of a part of repository.
    /// </summary>
    /// <example>The following example gets the revision of the current folder.
    /// <code><![CDATA[
    /// <Target Name="Version">
    ///   <HgVersion LocalPath=".">
    ///     <Output TaskParameter="Revision" PropertyName="Revision" />
    ///     <Output TaskParameter="RevisionId" PropertyName="RevisionId" />
    ///   </HgVersion>
    ///   <Message Text="Revision: $(Revision)"/>
    /// </Target>
    /// ]]></code>
    /// </example>

    public ref class HgVersion : public ToolTask {

    private:
        StringBuilder^ _outputBuffer;
        String^ _localPath;
        int _numRevision;
        String^ _idRevision;
        String^ _hgPath;

    public:
        HgVersion()
        {
            _numRevision = 0;
            _idRevision = gcnew String("");
            _outputBuffer = gcnew StringBuilder();
            _hgPath = Path::Combine( Environment::GetFolderPath(Environment::SpecialFolder::ProgramFiles), "TortoiseHg" );
        }

        [Required]
        property String^ LocalPath {
            String^ get() {
                return _localPath;
            }
            void set( String^ Value ) {
                _localPath = Value;
            }
        }

        property String^ HgPath {
            String^ get() {
                return _hgPath;
            }
            void set( String^ Value ) {
                _hgPath = Value;
            }
        }

        [Output]
        property int Revision {
            int get() {
                return _numRevision;
            }
            void set( int Value ) {
                _numRevision = Value;
            }
        }

        [Output]
        property String^ RevisionId {
            String^ get() {
                return _idRevision;
            }
            void set( String^ Value ) {
                _idRevision = Value;
            }
        }

    protected:
        virtual String^ GenerateFullPathToTool() override {
            return Path::Combine(_hgPath, ToolName);
        }

        virtual property MessageImportance StandardOutputLoggingImportance {
            MessageImportance get() override {
                return MessageImportance::Normal;
            }
        }

        virtual property String^ ToolName {
            String^ get() override {
                return "hg.exe";
            }
        }

        virtual String^ GenerateCommandLineCommands() override {
            DirectoryInfo^ localPath = gcnew DirectoryInfo(_localPath);
            return String::Format("log -q -l 1 \"{0}\"", localPath->FullName->Replace('\\', '/'));
        }

        virtual void LogEventsFromTextOutput(String^ singleLine, MessageImportance messageImportance) override {
            ToolTask::LogEventsFromTextOutput(singleLine, messageImportance);
            _outputBuffer->Append(singleLine);
        }

    public:
        virtual bool Execute() override {
            bool result = ToolTask::Execute();
            if (result)
            {
                ParseOutput();
            }
            return result;
        }

    private:
        void ParseOutput()
        {
            String^ buffer = _outputBuffer->ToString();
            int colon = buffer->IndexOf( ":" );
            if( colon >= 0 )
            {
                String^ num = buffer->Substring( 0, colon );
                _numRevision = _numRevision.Parse( num );
                _idRevision = buffer->Substring( colon+1 );
            }
            else
            {
                _numRevision = 0;
                _idRevision = gcnew String("<unversioned>");
            }
        }
    };

} // namespace
