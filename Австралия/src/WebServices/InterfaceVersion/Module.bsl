#Region Private

// Returns the array of version number names supported by the InterfaceName subsystem.
//
// Parameters:
// InterfaceName - String - subsystem name.
//
// Returns:
// Array of strings.
//
// Usage example:
//
// 	// Returns the file transfer WSProxy object for the specified version.
// 	// If TransferVersion = Undefined, it returns the basic version (1.0.1.1) proxy.
//  //
//	Function GetFileTransferProxy(Val ConnectionParameters, Val TransferVersion = Undefined)
//		// …………………………………………………
//	EndFunction
//
//	Function GetFromStorage(Val FileID, Val ConnectionParameters) Export
//
//		// Common features of all versions.
//		// …………………………………………………
//
//		// Consider versioning.
//		SupportedVersionsArray = StandardSubsystemsServer.GetSubsystemVersionArray(
//			AttachmentParameters, "FileTransferService");
//		If SupportedVersionsArray.Find("1.0.2.1") = Undefined Then
//			HasVersion2Support = False;
//			Proxy = GetFileTransferProxy(ConnectionParameters);
//		Else
//			HasVersion2Support = True;
//			Proxy = GetFileTransferProxy(ConnectionParameters "1.0.2.1");
//		EndIf
//
//		PartsNumber = Undefined;
//		PartSize = 20 * 1024; // Kb
//		If HasVersion2Suppopt Then
//	   		TransferID = Proxy.PrepareGetFile(FileID, PartSize, PartsCount);
//		Else
//			TransferID = Undefined;
//			Proxy.PrepareGetFile(FileID, PartSize, TransferID, PartCount);
//		EndIf
//
//		// Common features of all versions.
//		// …………………………………………………	
//
//	EndFunction
//
Function GetVersions(InterfaceName)
	
	VersionsArray = Undefined;
	
	SupportedVersionStructure = New Structure;
	
	SSLSubsystemsIntegration.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	CommonOverridable.OnDefineSupportedInterfaceVersions(SupportedVersionStructure);
	
	SupportedVersionStructure.Property(InterfaceName, VersionsArray);
	
	If VersionsArray = Undefined Then
		Return XDTOSerializer.WriteXDTO(New Array);
	Else
		Return XDTOSerializer.WriteXDTO(VersionsArray);
	EndIf;
	
EndFunction

#EndRegion