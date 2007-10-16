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
	/// Summarize the local revision(s) of a working copy.
	/// </summary>
	/// <example>The following example gets the revision of the current folder.
	/// <code><![CDATA[
	/// <Target Name="Version">
	///   <SvnVersion LocalPath=".">
	///     <Output TaskParameter="Revision" PropertyName="Revision" />
	///   </SvnVersion>
	///   <Message Text="Revision: $(Revision)"/>
	/// </Target>
	/// ]]></code>
	/// </example>

	public ref class SvnVersion : public ToolTask {

	private:
	    Regex^ _numberRegex;
		  StringBuilder^ _outputBuffer;
		  String^ _localPath;
		  String^ _options;
		  int _highRevision;
		  int _lowRevision;
		  bool _modifications;
		  bool _switched;
		  bool _exported;

  public:
	  SvnVersion()
   	{
   	  _lowRevision = -1;
   	  _highRevision = -1;
	    _outputBuffer = gcnew StringBuilder();
      _numberRegex = gcnew Regex( "\\d+", RegexOptions::Compiled );
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

		property String^ Options {
			String^ get() {
			  return _options;
			}
			void set( String^ Value ) {
			  _options = Value;
			}
		}

		[Output]
		property int Revision {
			int get() {
			  return _highRevision;
			}
			void set( int Value ) {
			  _highRevision = Value;
			}
		}

		[Output]
		property int HighRevision {
			int get() {
			  return _highRevision;
			}
			void set( int Value ) {
			  _highRevision = Value;
			}
		}

		[Output]
		property int LowRevision {
			int get() {
			  return _lowRevision;
			}
			void set( int Value ) {
			  _lowRevision = Value;
			}
		}

		[Output]
		property bool Modifications {
			bool get() {
			  return _modifications;
			}
			void set( bool Value ) {
			  _modifications = Value;
			}
		}

		[Output]
		property bool Switched {
			bool get() {
			  return _switched;
			}
			void set( bool Value ) {
			  _switched = Value;
			}
		}

		[Output]
		property bool Exported {
			bool get() {
			  return _exported;
			}
			void set( bool Value ) {
			  _exported = Value;
			}
		}

  protected:
		virtual String^ GenerateFullPathToTool() override {
		  ToolTask::ToolPath = Path::Combine(
				Environment::GetFolderPath(Environment::SpecialFolder::ProgramFiles),
				"Subversion\\bin"
		  );
			return Path::Combine(ToolTask::ToolPath, ToolName);
		}

		virtual property MessageImportance StandardOutputLoggingImportance {
			MessageImportance get() override {
			  return MessageImportance::Normal;
			}
		}

		virtual property String^ ToolName {
			String^ get() override {
			  return "svnversion.exe";
			}
		}

		virtual String^ GenerateCommandLineCommands() override {
			DirectoryInfo^ localPath = gcnew DirectoryInfo(_localPath);
			return String::Format("--no-newline {0} \"{1}\"", _options, localPath->FullName->Replace('\\', '/'));
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
			MatchCollection^ revisions = _numberRegex->Matches(buffer);
			
			for each (Match^ rm in revisions)
			{
				int revision;
				if (revision.TryParse(rm->Value, revision))
				{
					_lowRevision = Math::Min(revision, _lowRevision);
					_highRevision = Math::Max(revision, _highRevision);
				}
			}

			_modifications = buffer->Contains("M");
			_switched = buffer->Contains("S");
			_exported = buffer->Contains("exported");
			if (_exported) {
				Log->LogWarning("Local path is not working copy");
			}
		}
  };

} // namespace
