////////////////////////////////////////////////////////////////////////////////
// File operations subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Private

// Checks whether the scanning component is installed and is there is at least one scanner.
Function ScanCommandAvailable() Export
	
	Return FilesOperationsInternalClient.ScanCommandAvailable();
	
EndFunction

// Returns PutInUserWorkingDirectory session parameter.
Function UserWorkingDirectory() Export
	
	ParameterName = "StandardSubsystems.WorkingDirectoryAccessCheckExecuted";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, False);
	EndIf;
	
	DirectoryName =
		StandardSubsystemsClient.ClientRunParameters().PersonalFilesOperationsSettings.PathToLocalFileCache;
	
	// Already set.
	If DirectoryName <> Undefined
		AND NOT IsBlankString(DirectoryName)
		AND ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] Then
		
		Return DirectoryName;
	EndIf;
	
	If DirectoryName = Undefined Then
		DirectoryName = FilesOperationsInternalClient.SelectPathToUserDataDirectory();
		If NOT IsBlankString(DirectoryName) Then
			FilesOperationsInternalClient.SetUserWorkingDirectory(DirectoryName);
		Else
			ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] = True;
			Return ""; // Web client without file system extension
		EndIf;
	EndIf;
	
#If NOT WebClient Then
	
	// Create a directory for files.
	Try
		CreateDirectory(DirectoryName);
		TestDirectoryName = DirectoryName + "CheckAccess\";
		CreateDirectory(TestDirectoryName);
		DeleteFiles(TestDirectoryName);
	Except
		// The path does not exit or not enough rights to create a directory, using the default settings.
		// 
		DirectoryName = FilesOperationsInternalClient.SelectPathToUserDataDirectory();
		FilesOperationsInternalClient.SetUserWorkingDirectory(DirectoryName);
	EndTry;
	
#EndIf
	
	ApplicationParameters["StandardSubsystems.WorkingDirectoryAccessCheckExecuted"] = True;
	
	Return DirectoryName;
	
EndFunction

Function IsDirectoryFiles(FilesOwner) Export
	
	Return FilesOperationsInternalServerCall.IsDirectoryFiles(FilesOwner);
	
EndFunction

#EndRegion
