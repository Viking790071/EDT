#Region Public

// The function translates an arbitrary XDTO object between versions by the translation handlers 
// registered in the system, defining the resulting version by the namespace of the resulting 
// message.
//
// Parameters:
//  InitialObject - XDTODataObject - object to be translated.
//  ResultingVersion - string - number of the resulting interface version in the RR.{S|SS}.ZZ.CC format.
//  SourceVersionPackage - String - message version namespace.
//
// Returns:
//  XDTODataObject - object translation result.
//
Function TranslateToVersion(Val InitialObject, Val ResultingVersion, Val SourceVersionPackage = "") Export
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		SourceVersionPackage);
	ResultingVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		ResultingVersion);
	
	Return XDTOTranslationInternal.ExecuteTranslation(
		InitialObject,
		InitialVersionDescription,
		ResultingVersionDescription);
	
EndFunction

// The function translates an arbitrary XDTO object between versions by the translation handlers 
// registered in the system, defining the resulting version by the namespace of the resulting 
// message.
//
// Parameters:
//  InitialObject - XDTODataObject - object to be translated.
//  ResultingVersionPackage - String - resulting version namespace.
//  SourceVersionPackage - String - message version namespace.
//
// Returns:
//  XDTODataObject - object translation result.
//
Function TranslateToNamespace(Val InitialObject, Val ResultingVersionPackage, Val SourceVersionPackage = "") Export
	
	If InitialObject.Type().NamespaceURI = ResultingVersionPackage Then
		Return InitialObject;
	EndIf;
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		SourceVersionPackage);
	ResultingVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		ResultingVersionPackage);
	
	Return XDTOTranslationInternal.ExecuteTranslation(
		InitialObject,
		InitialVersionDescription,
		ResultingVersionDescription);
	
EndFunction

#EndRegion
