#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. It will be removed in the next library version.
// Returns the namespace of the current (used by the calling code) message interface version.
//
// Returns:
//   String - namespace of the current message interface version.
//
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/" + Version();
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns the current (used by the calling code) message interface version.
//
// Returns:
//   String - the version.
//
Function Version() Export
	
	Return "1.0.0.1";
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns the name of the application message interface.
//
// Returns:
//   String - application interface ID.
//
Function Public() Export
	
	Return "ApplicationExtensionsPermissions";
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Registers supported versions of message interface.
//
// Parameters:
//  SupportedVersionStructure - Structure - application interface name is passed as a key, while an 
//    array of supported versions is passed as a value.
//
Procedure RegisterInterface(Val SupportedVersionStructure) Export
	
	VersionsArray = New Array;
	VersionsArray.Add("1.0.0.1");
	SupportedVersionStructure.Insert(Public(), VersionsArray);
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Registers message handlers as message exchange channel handler.
//
// Parameters:
//  HandlerArray - Array - an array of handlers.
//
Procedure MessageChannelHandlers(Val HandlerArray) Export
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Returns action kind ID of configuration method call.
//
// Returns:
//   String - action kind ID.
//
Function ConfigurationMethodCallActionKind() Export
	
	Return "ConfigurationMethod"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns action kind ID of data processor method call.
//
// Returns:
//   String - action kind ID.
//
Function DataProcessorMethodCallActionKind() Export
	
	Return "DataProcessorMethod"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns parameter kind ID of startup key.
//
// Returns:
//   String - a parameter kind.
//
Function SessionKeyParameterKind() Export
	
	Return "SessionKey"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns parameter kind ID of fixed value.
//
// Returns:
//   String - a parameter kind ID.
//
Function ValuePropertyKind() Export
	
	Return "FixedValue"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns the parameter kind ID of the value to be saved.
//
// Returns:
//   String - action kind ID.
//
Function ValueToSaveParameterKind() Export
	
	Return "ValueToSave"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns parameter kind ID of saved value collection.
//
// Returns:
//   String - action kind ID.
//
Function ValueToSaveCollectionParameterKind() Export
	
	Return "ValueToSaveCollection"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns parameter kind ID of command execution parameter.
//
// Returns:
//   String - action kind ID.
//
Function CommandRunParameterParameterKind() Export
	
	Return "CommandRunParameter"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns parameter kind ID of the collection of related objects.
//
// Returns:
//   String - action kind ID.
//
Function ParameterKindRelatedObjects() Export
	
	Return "RelatedObjects"; // Do not localize.
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Constructor of a blank value table that is used as a description of safe mode scenario.
// 
//
// Returns:
//   ValueTable - a table with columns:
//     * ActionKind - String - action kind ID.
//     * MethodName - String - method name ID.
//     * Parameters - ValueTable - a table of parameters.
//     * ResultSaving - String - saving results.
//
Function NewScenario() Export
	
	Result = New ValueTable();
	Result.Columns.Add("ActionKind", New TypeDescription("String"));
	Result.Columns.Add("MethodName", New TypeDescription("String"));
	Result.Columns.Add("Parameters", New TypeDescription("ValueTable"));
	Result.Columns.Add("ResultSaving", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Adds stage of configuration method execution to data processor execution scenario in safe mode.
// 
//
// Parameters:
//  Scenario - ValueTable - see NewScenario. 
//  MethodName - String - a name of the configuration method meant to be called when executing a 
//    scenario step.
//  ResultSaving - String - a name of the scenario value to be saved. It will store the result of 
//    the method passed in the MethodName parameter.
//
// Returns:
//   ValueTableRow - see NewScenario. 
//
Function AddConfigurationMethod(Scenario, Val MethodName, Val ResultSaving = "") Export
	
	Return AddStage(Scenario, ConfigurationMethodCallActionKind(), MethodName, ResultSaving);
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Adds a stage that includes execution of a configuration method to safe mode data processor 
// execution scenario.
//
// Parameters:
//  Scenario - ValueTable - see NewScenario. 
//  MethodName - String - a name of the configuration method meant to be called when executing a 
//    scenario step.
//  ResultSaving - String - a name of the scenario value to be saved. It will store the result of 
//    the method passed in the MethodName parameter.
//
// Returns:
//   ValueTableRow - see NewScenario. 
//
Function AddDataProcessorMethod(Scenario, Val MethodName, Val ResultSaving = "") Export
	
	Return AddStage(Scenario, DataProcessorMethodCallActionKind(), MethodName, ResultSaving);
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Constructor of a blank value table that is used as a description of safe mode scenario item 
// parameters.
//
// Returns:
//   ValueTable - a table with columns:
//     * Kind - String - a parameter kind.
//     * Value - Arbitrary - a parameter value.
//
Function NewParameterTable() Export
	
	Result = New ValueTable();
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("Value");
	
	Return Result;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Adds a startup key of the current data processor to a parameter table     .
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod. 
//
Procedure AddSessionKey(Stage) Export
	
	AddParameter(Stage, SessionKeyParameterKind());
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Adds fixed value to parameter table.
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod.  
//  Value - Arbitrary - a fixed value.
//
Procedure AddValue(Step, Val Value) Export
	
	AddParameter(Step, ValuePropertyKind(), Value);
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Adds fixed value to parameter table.
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod.  
//  ValueToSave - String - a name of the variable to store the value inside the scenario.
//
Procedure AddValueToSave(Stage, Val ValueToSave) Export
	
	AddParameter(Stage, ValueToSaveParameterKind(), ValueToSave);
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Adds a collection of values to store to the table of parameters.
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod.  
//
Procedure AddCollectionOfValuesToSave(Stage) Export
	
	AddParameter(Stage, ValueToSaveCollectionParameterKind());
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Adds command execution parameter to parameter table.
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod.  
//  ParameterName - String - a name of the command parameter.
//
Procedure AddCommandRunParameter(Stage, Val ParameterName) Export
	
	AddParameter(Stage, CommandRunParameterParameterKind(), ParameterName);
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Adds the collection of related objects to a parameter table.
//
// Parameters:
//  Step - ValueTableRow - see AddConfigurationMethod or AddDataProcessorMethod.  
//
Procedure AddRelatedObjects(Stage) Export
	
	AddParameter(Stage, ParameterKindRelatedObjects());
	
EndProcedure

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}CreateComObject
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function COMObjectCreationType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "CreateComObject");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}CreateComObject.
//
// Parameters:
//  ProgID - String - ProgID of COM class, with which it is registered in the application.
//    For example, "Excel.Application".
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function PermissionToCreateCOMObject(Val ProgId, Val PackageUsed = Undefined) Export
	
	Type = COMObjectCreationType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.ProgId = ProgId;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function AddInAttachmentType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "AttachAddin");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin.
//
// Parameters:
//  CommonTemplateName - String - a name of the common template.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function AttachAddInFromCommonConfigurationTemplatePermission(Val CommonTemplateName, Val PackageUsed = Undefined) Export
	
	Type = AddInAttachmentType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.TemplateName = "CommonTemplate." + CommonTemplateName;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}AttachAddin.
//
// Parameters:
//  MetadataObject - MetadataObject - a metadata object.
//  TemplateName - String - a template name.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function AttachAddInFromConfigurationTemplatePermission(Val MetadataObject, Val TemplateName, Val PackageUsed = Undefined) Export
	
	Type = AddInAttachmentType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.TemplateName = MetadataObject.FullName() + ".Template" + TemplateName;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromExternalSoftware.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function FileReceivingFromExternalObjectType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetFileFromExternalSoftware");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromExternalSoftware.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function PermissionToGetFileFromExternalObject(Val PackageUsed = Undefined) Export
	
	Type = FileReceivingFromExternalObjectType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToExternalSoftware.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function TypeTransferFileToExternalObject(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SendFileToExternalSoftware");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToExternalSoftware.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function PermissionToSendFileToExternalObject(Val PackageUsed = Undefined) Export
	
	Type = TypeTransferFileToExternalObject(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromInternet.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - a message type.
//
Function DataReceivingFromInternetType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "GetFileFromInternet");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}GetFileFromInternet.
//
// Parameters:
//  Protocol - String - a protocol.
//  Server - String - a server.
//  Port - String - a port.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function PermissionToGetDataFromInternet(Val Protocol, Val Server, Val Port, Val PackageUsed = Undefined) Export
	
	Type = DataReceivingFromInternetType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.Protocol = Upper(Protocol);
	Permission.Host = Server;
	Permission.Port = Port;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToInternet.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function DataSendingToInternetType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SendFileToInternet");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SendFileToInternet.
//
// Parameters:
//  Protocol - String - a data transfer protocol being used.
//  Server - String - a server.
//  Port - String - a port.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function SendDataToInternetPermission(Val Protocol, Val Server, Val Port, Val PackageUsed = Undefined) Export
	
	Type = DataSendingToInternetType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.Protocol = Upper(Protocol);
	Permission.Host = Server;
	Permission.Port = Port;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SoapConnect.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function WSConnectionType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "SoapConnect");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}SoapConnect.
//
// Parameters:
//  WSDLAddress - String - WDSL publication address.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function WSConnectionPermission(Val WSDLAddress, Val PackageUsed = Undefined) Export
	
	Type = WSConnectionType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.WsdlDestination = WSDLAddress;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}DocumentPosting.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function DocumentPostingType(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "DocumentPosting");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns object {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}DocumentPosting.
//
// Parameters:
//  MetadataObject - MetadataObject - a metadata object.
//  WriteMode - DocumentWriteMode - a document write mode.
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTODataObject - permission.
//
Function DocumentPostingPermission(Val MetadataObject, Val WriteMode, Val PackageUsed = Undefined) Export
	
	Type = DocumentPostingType(PackageUsed);
	Permission = XDTOFactory.Create(Type);
	Permission.DocumentType = MetadataObject.FullName();
	If WriteMode = DocumentWriteMode.Posting Then
		Permission.Action = "Posting";
	Else
		Permission.Action = "UndoPosting";
	EndIf;
	
	Return Permission;
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}InternalFileHandler.
//
// Parameters:
//  PackageUsed - String - a namespace of the message interface version for which the message type 
//    is being received.
//
// Returns:
//  XDTOType - message type.
//
Function ParameterPassedFile(Val PackageUsed = Undefined) Export
	
	Return GenerateMessageType(PackageUsed, "InternalFileHandler");
	
EndFunction

// Obsolete. It will be removed in the next library version.
// Returns the value that matches "any restriction" value (*) during the registration of permissions 
// that are requested by additional data processor.
//
// Returns:
//  Undefined - any value.
//
Function AnyValue() Export
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Obsolete.
Function GenerateMessageType(Val PackageUsed, Val Type)
		
	If PackageUsed = Undefined Then
		PackageUsed = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageUsed, Type);
	
EndFunction

// Obsolete.
Function AddStage(Scenario, Val StageKind, Val MethodName, Val ResultSaving = "")
	
	Step = Scenario.Add();
	Step.ActionKind = StageKind;
	Step.MethodName = MethodName;
	Step.Parameters = NewParameterTable();
	If Not IsBlankString(ResultSaving) Then
		Step.ResultSaving = ResultSaving;
	EndIf;
	
	Return Step;
	
EndFunction

// Obsolete.
Procedure AddParameter(Step, Val ParameterKind, Val Value = Undefined)
	
	Parameter = Step.Parameters.Add();
	Parameter.Kind = ParameterKind;
	If Value <> Undefined Then
		Parameter.Value = Value;
	EndIf;
	
EndProcedure

// Obsolete.
// Converts permissions from version 2.1.3 format to version 2.2.2 format.
//
Function ConvertVersion_2_1_3_PermissionsTo_2_2_2_VersionPermissions(Val AdditionalReportOrDataProcessor, Val Permissions) Export
	
	Result = New Array();
	
	// If the data processor has commands that are scenarios, adding rights to work with temporary file 
	// directory.
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	ScenarioFilter = New Structure("StartupOption", Enums.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode);
	HasScenarios = AdditionalReportOrDataProcessor.Commands.FindRows(ScenarioFilter).Count() > 0;
	If HasScenarios Then
		Result.Add(ModuleSafeModeManager.PermissionToUseTempDirectory(True, True));
	EndIf;
	
	// Converting permissions to safe mode "expansion" notations.
	For Each Permission In Permissions Do
		
		If Permission.Type() = DataReceivingFromInternetType(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseInternetResource(
					Permission.Protocol,
					Permission.Host,
					Permission.Port));
			
		ElsIf Permission.Type() = DataSendingToInternetType(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseInternetResource(
					Permission.Protocol,
					Permission.Host,
					Permission.Port));
			
		ElsIf Permission.Type() = WSConnectionType(Package()) Then
			
			URIStructure = CommonClientServer.URIStructure(Permission.WsdlDestination);
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseInternetResource(
					URIStructure.Schema,
					URIStructure.ServerName,
					URIStructure.Port));
			
		ElsIf Permission.Type() = COMObjectCreationType(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToCreateCOMClass(
					Permission.ProgId,
					COMClassIDInBackwardCompatibilityMode(Permission.ProgId)));
			
		ElsIf Permission.Type() = AddInAttachmentType(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseAddIn(
					Permission.TemplateName));
			
		ElsIf Permission.Type() = FileReceivingFromExternalObjectType(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseTempDirectory(True, True));
			
		ElsIf Permission.Type() = TypeTransferFileToExternalObject(Package()) Then
			
			Result.Add(
				ModuleSafeModeManager.PermissionToUseTempDirectory(True, True));
			
		ElsIf Permission.Type() = DocumentPostingType(Package()) Then
			
			Result.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Obsolete.
Function COMClassIDInBackwardCompatibilityMode(Val ProgId)
	
	SupportedIDs = COMClassIDsInBackwardCompatibilityMode();
	CLSID = SupportedIDs.Get(ProgId);
	
	If CLSID = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Разрешение на использование COM-класса ""%1"" не может быть предоставлено дополнительной обработке,
				|работающей в режиме обратной совместимости с механизмом разрешений, реализованным в версии БСП 2.1.3.
				|Для использования COM-класса требуется переработать дополнительную обработку для работы без режима обратной совместимости.'; 
				|en = 'Permission to use COM class ""%1"" cannot be granted to the additional data processor
				|working in backward compatibility mode with mechanism of permissions realized in version of SL 2.1.3.
				|To use COM class, process additional data processor so that it operates without backward compatibility mode.'; 
				|pl = 'Uprawnienie do korzystania z klasy COM ""%1"" nie może być nadano przetwarzaniu dodatkowemu,
				|pracującemu w trybie kompatybilności odwrotnej z mechanizmem zezwoleń, realizowanym w wersji BPS 2.1.3.
				|W celu użycia klasy COM należy przetworzyć przetwarzanie dodatkowe do pracy bez trybu kompatybilności odwrotnej.';
				|es_ES = 'Permiso para utilizar la clase COM ""%1"" puede no otorgarse al procesador de datos adicional
				|que lanza en el modo de compatibilidad reversa con el mecanismo de permisos implementado en la versión SSL 2.1.3.
				|Para utilizar la clase COM, se requiere procesar el procesador de datos adicionales para trabajar sin el modo de compatibilidad reversa.';
				|es_CO = 'Permiso para utilizar la clase COM ""%1"" puede no otorgarse al procesador de datos adicional
				|que lanza en el modo de compatibilidad reversa con el mecanismo de permisos implementado en la versión SSL 2.1.3.
				|Para utilizar la clase COM, se requiere procesar el procesador de datos adicionales para trabajar sin el modo de compatibilidad reversa.';
				|tr = 'COM sınıfını kullanma izni, %1SSL 2.1.3 sürümünde uygulanan izin mekanizmasıyla geriye dönük uyumluluk modunda çalışan ek veri işlemcisine verilemez. 
				|COM sınıfını kullanmak için, 
				|geriye dönük uyumluluk modu olmadan çalışmak için ek veri işlemcisini işlemek gerekir.';
				|it = 'Il permesso di utilizzo della classe COM ""%1"" non può essere concesso all''elaboratore dati aggiuntivo
				|in modalità di retrocompatibilità con il meccanismo di permessi realizzato nella versione di SL 2.1.3.
				|Per utilizzare la classe COM, elaborare l''elaboratore dati aggiuntivo così che operi senza la modalità di retrocompatibilità.';
				|de = 'Die Berechtigung zur Verwendung der COM-Klasse ""%1"" kann für die weitere Verarbeitung im Abwärtskompatibilitätsmodus mit dem in der BSP-Version 2.1.3 implementierten
				|Berechtigungsmechanismus nicht erteilt werden.
				|Für die Verwendung der COM-Klasse ist es notwendig, die zusätzliche Verarbeitung zu überarbeiten, um ohne Abwärtskompatibilitätsmodus zu arbeiten.'"),
			ProgId);
		
	Else
		
		Return CLSID;
		
	EndIf;
	
EndFunction

// Obsolete.
Function COMClassIDsInBackwardCompatibilityMode()
	
	Result = New Map();
	
	// V83.ComConnector
	Result.Insert(CommonClientServer.COMConnectorName(), Common.COMConnectorID(CommonClientServer.COMConnectorName()));
	// Word.Application
	Result.Insert("Word.Application", "000209FF-0000-0000-C000-000000000046");
	// Excel.Application
	Result.Insert("Excel.Application", "00024500-0000-0000-C000-000000000046");
	
	Return Result;
	
EndFunction

#EndRegion
