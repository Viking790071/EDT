#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Please use SaaS.IsSeparatedConfiguration.
// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
//   Boolean - True if the configuration is separated.
//
Function IsSeparatedConfiguration() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		HasSeparators = ModuleSaaS.IsSeparatedConfiguration();
	Else
		HasSeparators = False;
	EndIf;
	
	Return HasSeparators;
	
EndFunction

// Obsolete. Please use SaaS.ConfigurationSeparators.
// Returns an array of the separators that are in the configuration.
//
// Returns:
//   FixedArray - an array of common attribute names used as separators.
//     
//
Function ApplicationSeparators() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		Separators = ModuleSaaS.ApplicationSeparators();
	Else
		Separators = New  Array;
	EndIf;
	
	Return Separators;
	
EndFunction

// Obsolete. Please use SaaS.CommonAttributeComposition.
// Returns the common attribute content by the passed name.
//
// Parameters:
//   Name - String - common attribute name.
//
// Returns:
//   CommonAttributeContent - list of metadata objects that include the common attribute.
//
Function CommonAttributeContent(Val Name) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		CommonAttributeComposition = ModuleSaaS.CommonAttributeContent(Name);
	Else
		CommonAttributeComposition = Undefined;
	EndIf;
	
	Return CommonAttributeComposition;
	
EndFunction

// Obsolete. Please use SaaS.IsSeparatedMetadataObject.
// Returns a flag that shows whether the metadata object is used in common separators.
//
// Parameters:
//   MetadataObjectName - String - an object name,
//   Separator - String - the name of the common separator that is checked if it separates the metadata object.
//
// Returns:
//   Boolean - True if the object is separated.
//
Function IsSeparatedMetadataObject(Val MetadataObjectName, Val Separator) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		IsSeparatedMetadataObject = ModuleSaaS.IsSeparatedMetadataObject(MetadataObjectName);
	Else
		IsSeparatedMetadataObject = False;
	EndIf;
	
	Return IsSeparatedMetadataObject;
	
EndFunction

// Obsolete. Please use SaaS.MainDataSeparator.
// Returns the name of the common attribute that is a separator of main data.
//
// Returns:
//   String - name of common separator.
//
Function MainDataSeparator() Export
	
	Result = "";
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		Result = ModuleSaaS.MainDataSeparator();
	EndIf;
	
	Return Result;
	
EndFunction

// Obsolete. Please use SaaS.AuxiliaryDataSeparator.
// Returns the name of the common attribute that is a separator of auxiliary data.
//
// Returns:
//   String - name of common separator.
//
Function AuxiliaryDataSeparator() Export
	
	Result = "";
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		Result = ModuleSaaS.AuxiliaryDataSeparator();
	EndIf;
	
	Return Result;
	
EndFunction

// Obsolete. Use Common.DataSeparationEnabled.
// Returns the data separation mode flag (conditional separation).
// 
// 
// Returns False if the configuration does not support data separation mode (does not contain 
// attributes to share).
//
// Returns:
//  Boolean - True if separation is enabled.
//         - False is separation is disabled or not supported.
//
Function DataSeparationEnabled() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		DataSeparationEnabled = ModuleSaaS.DataSeparationEnabled();
	Else
		DataSeparationEnabled = False;
	EndIf;
	
	Return DataSeparationEnabled;
	
EndFunction

// Obsolete. Use Common.SeparatedDataUsageAvailable.
// Returns a flag indicating whether separated data (included in the separators) can be accessed.
// The flag is session-specific, but can change its value if data separation is enabled on the 
// session run. So, check the flag right before addressing the shared data.
// 
// Returns True if the configuration does not support data separation mode (does not contain 
// attributes to share).
//
// Returns:
//   Boolean - True if separation is not supported or disabled or separation is enabled and 
//                    separators are set.
//          - False if separation is enabled and separators are not set.
//
Function SeparatedDataUsageAvailable() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SeparatedDataUsageAvailable = ModuleSaaS.SeparatedDataUsageAvailable();
	Else
		SeparatedDataUsageAvailable = True;
	EndIf;
	
	Return SeparatedDataUsageAvailable;
	
EndFunction

// Obsolete. Returns XSLTransform object created from the common template with the passed name.
// 
//
// Parameters:
//   CommonTemplateName - a name of common template of the BinaryData type that contains XSL 
//     transformation file.
//
// Returns:
//   XSLTransform - the XSLTransform object.
//
Function GetXSLTransformFromCommonTemplate(Val CommonTemplateName) Export
	
	TemplateData = GetCommonTemplate(CommonTemplateName);
	TransformFileName = GetTempFileName("xsl");
	TemplateData.Write(TransformFileName);
	
	Transform = New XSLTransform;
	Transform.LoadXSLStylesheetFromFile(TransformFileName);
	
	Try
		DeleteFiles(TransformFileName);
	Except
		WriteLogEvent(NStr("ru = 'Получение XSL'; en = 'Getting XSL transformation'; pl = 'Pobieranie XSL';es_ES = 'Recibir XSL';es_CO = 'Recibir XSL';tr = 'XSL alın';it = 'Ricezione trasformazione XSL';de = 'Erhalte XSL'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Transform;
	
EndFunction

// Obsolete. Please use SaaS.SessionStartedWithoutSeparators.
// Determines if the session was started without separators.
//
// Returns:
//   Boolean - True if the session is started without separators.
//
Function SessionWithoutSeparators() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	Return SessionWithoutSeparators;
	
EndFunction

// Obsolete. Use the following functions to receive the required properties:
//  IsSystemAdministrator property - Users.IsFullUser(, True);
//  IsApplicationAdministrator property - Users.IsFullUser();
//  SaaSModel property - CommonSeparationEnabled();
//  Standalone property - Common.IsStandaloneWorkplace();
//  Local property - is neither Standalone nor SaaSModel;
//  File property - Common.FileInfobase();
//  ClientServer property - not Common.FileInfobase();
//  LocalFile property - both Local and File (see above);
//  LocalClientServer property - both Local and ClientServer (see above);
//  IsWindowsClient property - CommonClientServer.IsWindowsClient();
//  IsLinuxClient property - CommonClientServer.IsLinuxClient();
//  IsOSXClient property - CommonClientServer.IsOSXClient();
//  IsWebClient property - CommonClientServer.IsWebClient().
// 
// Determines the current application run mode.
// It is used in application setting panels for hiding  items intended not for all run modes.
//
//   Five interfaces are available in the settings panels:
//     - For the service administrator in the subscriber data area (SAS).
//     - For the subscriber administrator (SA).
//     - For the local solution administrator in the client/server mode (LCS)
//     - For the local solution administrator in the file mode (LF).
//     - For the standalone workstation administrator (SWP).
//   
//   The SAS and SA interfaces are split by hiding groups and items of a form for all roles, except 
//     FullAdministrator.
//   
//   The service administrator that logs on the data area should see the same settings as the 
//     subscriber administrator with the service settings (shared).
//     
//
// Returns:
//   Structure - settings that describe the current user rights and the current application run mode.
//     By rights:
//       * IsSystemAdministrator - Boolean - True if the infobase administration right is granted.
//       * IsApplicationAdministrator - Boolean - True if access to all "applied" infobase data is 
//                                              granted.
//     By infobase run modes:
//       * SaaSModel - Boolean - True if the configuration has separators and they are conditionally enabled.
//       * Local - Boolean - True if the application runs in usual mode (not in SaaS mode or 
//                                    standalone workplace mode).
//       * Standalone - Boolean - True if the application runs in the SWP mode (standalone workplace).
//       * File - Boolean - True if the applications runs in file mode.
//       * ClientServer - Boolean - True if the application runs in client/server mode.
//       * LocalFile - Boolean - True if the application runs in usual file mode.
//       * LocalClientServer - Boolean - True if the application runs in usual client server mode.
//     By client part functionality:
//       * IsLinuxClient - Boolean - True if the client application is running on OC Linux.
//       * IsWebClient - Boolean - True if the client application is a web client.
//
Function ApplicationRunMode() Export
	RunMode = New Structure;
	
	// Current user rights.
	RunMode.Insert("IsApplicationAdministrator", Users.IsFullUser(, False, False)); // SA, SAS, LCS, LF
	RunMode.Insert("IsSystemAdministrator",   Users.IsFullUser(, True, False)); // SAS, LCS, LF
	
	// Server run modes.
	RunMode.Insert("SaaSModel", DataSeparationEnabled()); // SAS, SA
	RunMode.Insert("Local",     GetFunctionalOption("LocalMode")); // LCS, LF
	RunMode.Insert("Standalone",    GetFunctionalOption("StandaloneMode")); // SWP
	RunMode.Insert("File",        False); // SAS, SA, LF
	RunMode.Insert("ClientServer", False); // SAS, SA, LCS
	
	If Common.FileInfobase() Then
		RunMode.File = True;
	Else
		RunMode.ClientServer = True;
	EndIf;
	
	RunMode.Insert("LocalFile",
		RunMode.Local AND RunMode.File); // LF
	RunMode.Insert("LocalClientServer",
		RunMode.Local AND RunMode.ClientServer); // LCS
	
	// Client run modes.
	RunMode.Insert("IsWindowsClient", CommonClientServer.IsWindowsClient());
	RunMode.Insert("IsLinuxClient"  , CommonClientServer.IsLinuxClient());
	RunMode.Insert("IsOSXClient"    , CommonClientServer.IsOSXClient());
	RunMode.Insert("IsWebClient"    , CommonClientServer.IsWebClient());
	
	Return RunMode;
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Returns True if the application is running in the standalone workplace mode.
Function IsStandaloneWorkplace() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		Return False;
	EndIf;
	
	ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
	
	Return ModuleDataExchangeServer.IsStandaloneWorkplace();
	
EndFunction

// Metadata object availability by functional options.
Function ObjectsEnabledByOption() Export
	
	Parameters = New Structure(CommonCached.InterfaceOptions());
	
	ObjectsEnabled = New Map;
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		Value = -1;
		For Each Item In FunctionalOption.Content Do
			If Item.Object = Undefined Then
				Continue;
			EndIf;
			If Value = -1 Then
				Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
			EndIf;
			FullName = Item.Object.FullName();
			If Value = True Then
				ObjectsEnabled.Insert(FullName, True);
			Else
				If ObjectsEnabled[FullName] = Undefined Then
					ObjectsEnabled.Insert(FullName, False);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	Return New FixedMap(ObjectsEnabled);
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Please use SaaS.SeparatedMetadataObjects.
// Returns a list of full names of all metadata objects used in the common separator attribute 
// (whose name is passed in the Separator parameter) and values of the object metadata properties 
// that can be required for further processing in universal algorithms.
// In case of sequences and document journals the function determines whether they are separated by included documents: any one from the sequence or journal.
//
// Parameters:
//  Separator - string, name of the common separator.
//
// Returns:
// FixedMap,
//  Key - string, full name of the metadata object,
//  Value - FixedStructure,
//    Name - string, name of the metadata object,
//    Separator - string, name of the separator that separates the metadata object,
//    ConditionalSeparation - String - full name of the metadata object that shows whether the 
//      metadata object data separation is enabled.
//
Function SeparatedMetadataObjects(Val Separator) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		Result = ModuleSaaS.SeparatedMetadataObjects(Separator);
	Else
		Result = New FixedMap(New Map);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Parameters applied to command interface items associated with parametric functional options.
Function InterfaceOptions() Export 
	
	InterfaceOptions = New Structure;
	CommonOverridable.OnDetermineInterfaceFunctionalOptionsParameters(InterfaceOptions);
	Return New FixedStructure(InterfaceOptions);
	
EndFunction

#EndRegion
