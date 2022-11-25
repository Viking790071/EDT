#Region Public

// Attaches an external report or data processor and returns the name of the attached report or data processor.
// Then registers the report or data processor in the application with a unique name. You can use 
// this name to create a report or data processor object or open its forms.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a data processor to attach.
//
// Returns:
//   * String       - a name of the attached report or data processor.
//   * Undefined - if an invalid reference is passed.
//
Function AttachExternalDataProcessor(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	SaaSIntegration.OnAttachExternalDataProcessor(Ref, StandardProcessing, Result);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	// Validating the passed parameters.
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	// Attaching.
	#If ThickClientOrdinaryApplication Then
		DataProcessorName = GetTempFileName();
		DataProcessorStorage = Common.ObjectAttributeValue(Ref, "DataProcessorStorage");
		BinaryData = DataProcessorStorage.Get();
		BinaryData.Write(DataProcessorName);
		Return DataProcessorName;
	#EndIf
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	StartParameters = Common.ObjectAttributesValues(Ref, "SafeMode, DataProcessorStorage");
	AddressInTempStorage = PutToTempStorage(StartParameters.DataProcessorStorage.Get());
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If UseSecurityProfiles Then
		
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Ref);
		
		If SafeMode = Undefined Then
			SafeMode = True;
		EndIf;
		
	Else
		
		SafeMode = GetFunctionalOption("StandardSubsystemsSaaS") Or StartParameters.SafeMode;
		
		If SafeMode Then
			PermissionQuery = New Query(
				"SELECT TOP 1
				|	AdditionalReportAndDataProcessorPermissions.LineNumber,
				|	AdditionalReportAndDataProcessorPermissions.PermissionKind
				|FROM
				|	Catalog.AdditionalReportsAndDataProcessors.Permissions AS AdditionalReportAndDataProcessorPermissions
				|WHERE
				|	AdditionalReportAndDataProcessorPermissions.Ref = &Ref");
			PermissionQuery.SetParameter("Ref", Ref);
			HasPermissions = Not PermissionQuery.Execute().IsEmpty();
			
			CompatibilityMode = Common.ObjectAttributeValue(Ref, "PermissionCompatibilityMode");
			If CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2
				AND HasPermissions Then
				SafeMode = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	WriteComment(Ref, NStr("ru = 'Подключение, БезопасныйРежим = ""%1"".'; en = 'Attachment, SafeMode = ""%1.""'; pl = 'Połączenie, SafeMode = ""%1"".';es_ES = 'Conexión, ModoSeguro = ""%1"".';es_CO = 'Conexión, ModoSeguro = ""%1"".';tr = 'Bağlantı, SafeMode = ""%1"".';it = 'Allegato, SafeMode = ""%1.""';de = 'Verbindung, AbgesicherterModus = ""%1"".'"), SafeMode);
	
	If Common.HasUnsafeActionProtection() Then
		DataProcessorName = Manager.Connect(AddressInTempStorage, , SafeMode,
			Common.ProtectionWithoutWarningsDetails());
	Else
		DataProcessorName = Manager.Connect(AddressInTempStorage, , SafeMode);
	EndIf;
	
	Return DataProcessorName;
	
EndFunction

// Returns an external report or data processor object.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a report data processor to attach.
//
// Returns:
//   * ExternalDataProcessorObject - attached data processor object.
//   * ExternalReportObject     - attached report object.
//   * Undefined           - if an invalid reference is passed.
//
Function ExternalDataProcessorObject(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	SaaSIntegration.OnCreateExternalDataProcessor(Ref, StandardProcessing, Result);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	
	// Attaching.
	DataProcessorName = AttachExternalDataProcessor(Ref);
	
	// Validating the passed parameters.
	If DataProcessorName = Undefined Then
		Return Undefined;
	EndIf;
	
	// Getting an object instance.
	If Ref.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		OR Ref.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	Return Manager.Create(DataProcessorName);
	
EndFunction

// Generates a print form based on an external source.
//
// Parameters:
//   AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - an external data processor.
//   SourceParameters            - Structure - a structure with the following properties:
//       * CommandID - String - a list of comma-separated templates.
//       * RelatedObjects    - Array
//   PrintFormCollection - ValueTable - generated spreadsheet documents (return parameter.)
//   PrintObjects         - ValueList - a correspondence between the objects and names of a 
//                                             spreadsheet document print areas. Value - Object, 
//                                             Presentation - a name of the area the object (return parameter) was displayed in.
//   OutputParameters       - Structure       - additional parameters of generated spreadsheet 
//                                             documents (return parameter).
//
Procedure PrintByExternalSource(AdditionalDataProcessorRef, SourceParameters, PrintFormsCollection,
	PrintObjects, OutputParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.PrintByExternalSource(
			AdditionalDataProcessorRef,
			SourceParameters,
			PrintFormsCollection,
			PrintObjects,
			OutputParameters);
	EndIf;
	
EndProcedure

// Generates a details template for external report or data processor, to be filled later.
//
// Parameters:
//   SLVersion - String - a Standard subsystem library version expected by the external data 
//                        processor or report mechanisms. See StandardSubsystemsServer. LibraryVersion.
//
// Returns:
//   Structure - parameters of the external report or data processor:
//       * Kind - String - a kind of the external report or data processor. To specify the kind, use functions
//           AdditionalReportsAndDataProcessorsClientServer.DataProcessorKind<KindName>.
//           You can also specify the kind explicitly:
//           PrintForm,
//           ObjectFilling,
//           RelatedObjectCreation,
//           Report,
//           MessageTemplate,
//           AdditionalDataProcessor, or
//           AdditionalReport.
//       
//       * Version - String - a version of the report or data processor (later on data processor).
//           Conforms to "<senior number>.<junior number>" format.
//       
//       * Assignment - Array - full names of the configuration objects (String) for which the data processor is intended for.
//                               Optional property.
//       
//       * Description - String - a presentation for administrator (catalog item description).
//                                 If empty, a presentation of external data processor metadata object is used.
//                                 Optional property.
//       
//       * SafeMode - Boolean - a flag indicating whether the external data processor is attached in safe mode.
//                                    True by default (data processor runs in safe mode).
//                                    In safe mode:
//                                    Privileged mode is ignored.
//                                    The following external (relative to the 1C:Enterprise platform) actions are prohibited:
//                                      COM;
//                                      Loading add-ins.
//                                      Running external applications and operating system commands.
//                                      Accessing file system except for temporary files.
//                                      Accessing the Internet.
//                                    Optional property.
//       
//       * Permissions - Array - additional permissions required for the external data processor in safe mode.
//                               ArrayItem - XDTODataObject - permission of kind
//                               {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}PermissionBase.
//                               To generate a permission description, use functions
//                               SafeModeManager.Permission<PermissionKind>(<PermissionParameters>).
//                               Optional property.
//       
//       * Information - String - a short information on the external data processor.
//                               It is recommended to provide the data processor functionality for administrator in this parameter.
//                               If empty, a comment of external data processor metadata object is used.
//       
//       * SLVersion - String - optional. Library version expected by the external data processor mechanisms.
//                              See StandardSubsystemsServer.LibraryVersion. 
//                              Optional property.
//       
//       * DefineFormSettings - Boolean - only for the additional reports attached to the ReportForm common form.
//                                             Allows to override some settings of the common report 
//                                             form and subscribe to its events.
//                                             If True, define the procedure in the report object module using the following template:
//           
//           // Define settings of the "Report options" subsystem common report form.
//           //
//           // Parameters:
//           //  Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//           //      Undefined when called without a context.
//           //   VariantKey - String, Undefined -  a predefined report option name
//           //       or UUID of a custom one.
//           //      Undefined when called without a context.
//           //   Settings - Structure - see the return value of
//           //       ReportsClientServer.GetDefaultReportSettings().
//           //
//           Procedure DefineFormSettings(Form, VariantKey, Settings) Export
//           	// Procedure code.
//           EndProcedure
//           
//           For more information, see help for subsystems "Additional reports and data processors" and "Report options".
//           Optional property.
//       
//       * Commands - ValueTable - settings of the commands provided by the external data processor (optional for reports):
//           ** ID - String - command internal name. For external print forms (when Kind = "PrintForm"):
//                 ID can contain comma-separated names of one or more print commands.
//                  For more information, see function CreatePrintCommandCollection() of common 
//                 module PrintManager, column ID. 
//           ** Presentation - String - user presentation of the command.
//           ** Usage - String - command type:
//               ClientMethodCall,
//               ServerMethodCall,
//               FormFilling,
//               FormOpening, or
//               ScenarioInSafeMode.
//               To receive command types, use functions
//               AdditionalReportsAndDataProcessorsClientServer.CommandType<TypeName>.
//               Comments to these functions contain templates of command handler procedures.
//           ** ShowNotification - Boolean - if True, show "Executing command..." notification upon command execution.
//              It is used for all command types except for commands for opening a form (Usage = "FormOpening".)
//           ** Modifier - String - additional command classification.
//               For external print forms (when Kind = "PrintForm"):
//                 "PrintMXL" - for print forms generated on the basis of spreadsheet templates.
//               For data import from file (when Kind = "PrintForm" and Usage = "DataImportFromFiles"):
//                 Modifier is required. It must contain the full name of the metadata object 
//                 (catalog) the data is imported for.
//                 
//           ** Hide - Boolean - optional. Shows whether it is a service command.
//               If True, the command is hidden from the additional object card.
//
Function ExternalDataProcessorInfo(SSLVersion = "") Export
	RegistrationParameters = New Structure;
	
	RegistrationParameters.Insert("Kind", "");
	RegistrationParameters.Insert("Version", "0.0");
	RegistrationParameters.Insert("Purpose", New Array);
	RegistrationParameters.Insert("Description", Undefined);
	RegistrationParameters.Insert("SafeMode", True);
	RegistrationParameters.Insert("Information", Undefined);
	RegistrationParameters.Insert("SSLVersion", SSLVersion);
	RegistrationParameters.Insert("DefineFormSettings", False);
	
	TabularSectionAttributes = Metadata.Catalogs.AdditionalReportsAndDataProcessors.TabularSections.Commands.Attributes;
	
	CommandsTable = New ValueTable;
	CommandsTable.Columns.Add("Presentation", TabularSectionAttributes.Presentation.Type);
	CommandsTable.Columns.Add("ID", TabularSectionAttributes.ID.Type);
	CommandsTable.Columns.Add("Use", New TypeDescription("String"));
	CommandsTable.Columns.Add("ShowNotification", TabularSectionAttributes.ShowNotification.Type);
	CommandsTable.Columns.Add("Modifier", TabularSectionAttributes.Modifier.Type);
	CommandsTable.Columns.Add("Hide",      TabularSectionAttributes.Hide.Type);
	CommandsTable.Columns.Add("CommandsToReplace", TabularSectionAttributes.CommandsToReplace.Type);
	
	RegistrationParameters.Insert("Commands", CommandsTable);
	RegistrationParameters.Insert("Permissions", New Array);
	
	Return RegistrationParameters;
EndFunction

// Executes a data processor command and returns the result.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   CommandParameters - Structure - parameters of the command.
//       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - a catalog item.
//       * CommandID - String - name of the command being executed.
//       * RelatedObjects    - Array - references to the objects used by the data processor. 
//                                         Mandatory for assignable data processors.
//   ResultAddress - String - optional. Address of a temporary storage where the execution result 
//                              will be stored.
//
// Returns:
//   Structure - execution result to be passed to client.
//   Undefined - if ResultAddress is passed.
//
Function ExecuteCommand(CommandParameters, ResultAddress = Undefined) Export
	
	If TypeOf(CommandParameters.AdditionalDataProcessorRef) <> Type("CatalogRef.AdditionalReportsAndDataProcessors")
		Or CommandParameters.AdditionalDataProcessorRef = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	ExternalObject = ExternalDataProcessorObject(CommandParameters.AdditionalDataProcessorRef);
	CommandID = CommandParameters.CommandID;
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, ResultAddress);
	
	Return ExecutionResult;
	
EndFunction

// Executes a data processor command directly from the external object form, and returns the execution result.
// For usage example, see AdditionalReportsAndDataProcessorsClient.ExecuteCommnadInBackground(). 
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   CommandID - String    - the command name as it is specified in function ExternalDataProcessorInfo() in the object module.
//   CommandParameters     - Structure - parameters of the command.
//                                      See AdditionalReportsAndDataProcessorsClient. ExecuteCommandInBackground().
//   Form                - ClientApplicationForm - a form to return the result in.
//
// Returns:
//   Structure - for internal use.
//
Function ExecuteCommandFromExternalObjectForm(CommandID, CommandParameters, Form) Export
	
	ExternalObject = Form.FormAttributeToValue("Object");
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, Undefined);
	Return ExecutionResult;
	
EndFunction

// Generates a list of sections where the additional report calling command is available.
//
// Returns:
//   Array - an array of Subsystem metadata objects - metadata of the sections where the list of 
//                                                    commands of additional reports is displayed.
//
Function AdditionalReportSections() Export
	MetadataSections = New Array;
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports(MetadataSections);
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithAdditionalReports(MetadataSections);
	EndIf;
	
	Return MetadataSections;
EndFunction

// Generates a list of sections where the additional data processor calling command is available.
//
// Returns:
//   Array - an array of Subsystem metadata objects - metadata of the sections where the list of 
//   commands of additional data processors is displayed.
//
Function AdditionalDataProcessorSections() Export
	MetadataSections = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleDataProcessorsControlPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleDataProcessorsControlPanelSSL.OnDefineSectionsWithAdditionalDataProcessors(MetadataSections);
	EndIf;
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalDataProcessors(MetadataSections);
	
	Return MetadataSections;
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use ExternalDataProcessorObject.
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a report data processor to attach.
//
// Returns:
//   * ExternalDataProcessorObject - attached data processor object.
//   * ExternalReportObject     - attached report object.
//   * Undefined           - if an invalid reference is passed.
//
Function GetExternalDataProcessorsObject(Ref) Export
	
	Return ExternalDataProcessorObject(Ref);
	
EndFunction

// Obsolete. Use AttachableCommands.OnCreateAtServer.
//
// Parameters:
//   Form - ClientApplicationForm - a form.
//   FormType - String - a form type.
//
Procedure OnCreateAtServer(Form, FormType = Undefined) Export
	Return;
EndProcedure

// Obsolete. Use AttachableCommands.ExecuteCommand.
//
// Executes an assignable command in context from the form of the related object.
// Intended to be called by the subsystem script from the item form of an assignable object (catalog, 
// document, etc).
//
// Important: Checking functional option UseAdditionalReportsAndDataProcessors
// must be executed by the calling code.
//
// Parameters:
//   Form               - ClientApplicationForm - a form the command is called from.
//   ItemName         - String           - name of the form command that is being executed.
//   ExecutionResult - Structure        - for internal use.
//
Procedure ExecuteAssignableCommandAtServer(Form, ItemName, ExecutionResult = Undefined) Export
	
	Return;
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Determines a list of metadata objects to which an assignable data processor of the specified kind can be applied.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportAndDataProcessorKinds - a kind of external data processor.
//
// Returns:
//   ValueTable - description of metadata object.
//       * Metadata - MetadataObject - a metadata object attached to the kind.
//       * FullName - String - a full name of the metadata object. Example: Catalog.Currencies.
//       * Ref     - CatalogRef.MetadataObjectIDs - a reference to the metadata object.
//       * Kind        - String - a kind of the metadata object.
//       * Presentation       - String - a presentation of the metadata object.
//       * FullPresentation - String - a presentation of metadata object name and kind.
//   Undefined - if invalid Kind is passed.
//
Function AttachedMetadataObjects(Kind) Export
	Result = New ValueTable;
	Result.Columns.Add("Metadata");
	Result.Columns.Add("FullName", New TypeDescription("String"));
	Result.Columns.Add("Ref", New TypeDescription("CatalogRef.MetadataObjectIDs, CatalogRef.ExtensionObjectIDs"));
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("FullPresentation", New TypeDescription("String"));
	
	Result.Indexes.Add("Ref");
	Result.Indexes.Add("Kind");
	Result.Indexes.Add("FullName");
	
	TypeOrMetadataArray = New Array;
	
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		
		TypeOrMetadataArray = Metadata.DefinedTypes.ObjectWithAdditionalCommands.Type.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate Then
		
		If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
			ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
			TypeOrMetadataArray = ModuleMessageTemplatesInternal.MessagesTemplatesSources()
		Else
			Return Result;
		EndIf;
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		
		If Common.SubsystemExists("StandardSubsystems.Print") Then
			ModulePrintManager = Common.CommonModule("PrintManagement");
			TypeOrMetadataArray = ModulePrintManager.PrintCommandsSources()
		Else
			Return Result;
		EndIf;
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		
		TypeOrMetadataArray = AdditionalDataProcessorSections();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		TypeOrMetadataArray = AdditionalReportSections();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	For Each TypeOrMetadata In TypeOrMetadataArray Do
		If TypeOf(TypeOrMetadata) = Type("Type") Then
			MetadataObject = Metadata.FindByType(TypeOrMetadata);
			If MetadataObject = Undefined Then
				Continue;
			EndIf;
		Else
			MetadataObject = TypeOrMetadata;
		EndIf;
		
		TableRow = Result.Add();
		TableRow.Metadata = MetadataObject;
		
		If MetadataObject = AdditionalReportsAndDataProcessorsClientServer.DesktopID() Then
			TableRow.FullName = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
			TableRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
			TableRow.Kind = "Subsystem";
			TableRow.Presentation = NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'");
		Else
			TableRow.FullName = MetadataObject.FullName();
			TableRow.Ref = Common.MetadataObjectID(MetadataObject);
			TableRow.Kind = Left(TableRow.FullName, StrFind(TableRow.FullName, ".") - 1);
			TableRow.Presentation = MetadataObject.Presentation();
		EndIf;
		
		TableRow.FullPresentation = TableRow.Presentation + " (" + TableRow.Kind + ")";
	EndDo;
	
	Return Result;
EndFunction

// Generates a new query used to get a command table for additional reports or data processors.
//
// Parameters:
//   DataProcessorsKind - EnumRef.AdditionalReportAndDataProcessorKinds - a kind of data processor.
//   Placement - CatalogRef.MetadataObjectsIDs, String - a reference or a full name of the metadata 
//       object linked to the additional reports and data processors.
//       Global data processors are located in the sections, while context ones are used in catalogs and documents.
//   IsObjectForm - Boolean - optional.
//       Type of forms that contain context additional reports and data processors.
//       True - only reports and data processors linked to object forms.
//       False - only reports and data processors linked to list forms.
//   CommandTypes - EnumRef.AdditionalReportsAndDataProcessorsPublicationOptions - a type of the received commands.
//       - Array - command types to obtain.
//           * EnumRef.AdditionalReportsAndDataProcessorsPublicationOptions
//   EnabledOnly - Boolean - optional.
//       Type of forms that contain context additional reports and data processors.
//       True - only reports and data processors linked to object forms.
//       False - only reports and data processors linked to list forms.
//
// Returns:
//   ValueTable - commands of additional reports and data processors.
//       * Ref - CatalogRef.AdditionalReportsAndDataProcessors - a reference to the additional report or data processor.
//       * ID - String - command ID as it is specified by the developer of the additional object.
//       * RunningVariant - EnumRef.AdditionalDataProcessorCallMethods - 
//           a method of calling the additional object command.
//       * Presentation - String - a command name in the user interface.
//       * ShowNotification - Boolean - show user notification when a command is executed.
//       * Modifier - String - command modifier.
//
Function NewQueryByAvailableCommands(DataProcessorsKind, Placement, IsObjectForm = Undefined, CommandTypes = Undefined, EnabledOnly = True) Export
	Query = New Query;
	
	If TypeOf(Placement) = Type("CatalogRef.MetadataObjectIDs") Then
		ParentOrSectionReference = Placement;
	Else
		If ValueIsFilled(Placement) Then
			ParentOrSectionReference = Common.MetadataObjectID(Placement);
		Else
			ParentOrSectionReference = Undefined;
		EndIf;
	EndIf;
	
	If ParentOrSectionReference <> Undefined Then // Filter by parent is set.
		AreGlobalDataProcessors = (
			DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
			Or DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor);
		
		// Calls used for global and for assignable data processors are fundamentally different.
		If AreGlobalDataProcessors Then
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	AdditionalReportsAndDataProcessors.Ref
			|INTO ttRefs
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors.Sections AS TableSections
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
			|		ON (TableSections.Section = &SectionRef)
			|			AND TableSections.Ref = AdditionalReportsAndDataProcessors.Ref
			|WHERE
			|	AdditionalReportsAndDataProcessors.Kind = &Kind
			|	AND NOT AdditionalReportsAndDataProcessors.DeletionMark
			|	AND AdditionalReportsAndDataProcessors.Publication = &Publication
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CommandsTable.Ref,
			|	CommandsTable.ID,
			|	CommandsTable.CommandsToReplace,
			|	CommandsTable.StartupOption,
			|	CommandsTable.Presentation,
			|	CommandsTable.ShowNotification,
			|	CommandsTable.Modifier,
			|	ISNULL(QuickAccess.Available, FALSE) AS Use
			|INTO SummaryTable
			|FROM
			|	ttRefs AS ReferencesTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable
			|		ON ReferencesTable.Ref = CommandsTable.Ref
			|			AND (CommandsTable.Hide = FALSE)
			|			AND (CommandsTable.StartupOption IN (&CommandTypes))
			|		LEFT JOIN InformationRegister.DataProcessorAccessUserSettings AS QuickAccess
			|		ON (CommandsTable.Ref = QuickAccess.AdditionalReportOrDataProcessor)
			|			AND (CommandsTable.ID = QuickAccess.CommandID)
			|			AND (QuickAccess.User = &CurrentUser)
			|WHERE
			|	ISNULL(QuickAccess.Available, FALSE)";
			Query.SetParameter("SectionRef", ParentOrSectionReference);
			
			If Not EnabledOnly Then
				QueryText = StrReplace(QueryText,
					"WHERE
					|	ISNULL(QuickAccess.Available, FALSE)",
					"");
			EndIf;
			
		Else
			
			QueryText =
			"SELECT ALLOWED DISTINCT
			|	AssignmentTable.Ref
			|INTO ttRefs
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AssignmentTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
			|		ON (AssignmentTable.RelatedObject = &ParentRef)
			|			AND AssignmentTable.Ref = AdditionalReportsAndDataProcessors.Ref
			|			AND (AdditionalReportsAndDataProcessors.DeletionMark = FALSE)
			|			AND (AdditionalReportsAndDataProcessors.Kind = &Kind)
			|			AND (AdditionalReportsAndDataProcessors.Publication = &Publication)
			|			AND (AdditionalReportsAndDataProcessors.UseForListForm = TRUE)
			|			AND (AdditionalReportsAndDataProcessors.UseForObjectForm = TRUE)
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CommandsTable.Ref,
			|	CommandsTable.ID,
			|	CommandsTable.CommandsToReplace,
			|	CommandsTable.StartupOption,
			|	CommandsTable.Presentation,
			|	CommandsTable.ShowNotification,
			|	CommandsTable.Modifier,
			|	UNDEFINED AS Use
			|INTO SummaryTable
			|FROM
			|	ttRefs AS ReferencesTable
			|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable
			|		ON ReferencesTable.Ref = CommandsTable.Ref
			|			AND (CommandsTable.Hide = FALSE)
			|			AND (CommandsTable.StartupOption IN (&CommandTypes))";
			
			Query.SetParameter("ParentRef", ParentOrSectionReference);
			
		EndIf;
		
	Else
		
		QueryText =
		"SELECT ALLOWED
		|	CommandsTable.Ref,
		|	CommandsTable.ID,
		|	CommandsTable.CommandsToReplace,
		|	CommandsTable.StartupOption,
		|	CommandsTable.Presentation AS Presentation,
		|	CommandsTable.ShowNotification,
		|	CommandsTable.Modifier,
		|	UNDEFINED AS Use
		|INTO SummaryTable
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandsTable
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
		|		ON CommandsTable.Ref = AdditionalReportsAndDataProcessors.Ref
		|			AND (AdditionalReportsAndDataProcessors.Kind = &Kind)
		|			AND (CommandsTable.StartupOption IN (&CommandTypes))
		|			AND (AdditionalReportsAndDataProcessors.Publication = &Publication)
		|			AND (AdditionalReportsAndDataProcessors.DeletionMark = FALSE)
		|			AND (AdditionalReportsAndDataProcessors.UseForListForm = TRUE)
		|			AND (AdditionalReportsAndDataProcessors.UseForObjectForm = TRUE)
		|			AND (CommandsTable.Hide = FALSE)";
		
	EndIf;
	
	// Disabling filters by list and object form.
	If IsObjectForm <> True Then
		QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors.UseForObjectForm = TRUE)", "");
	EndIf;
	If IsObjectForm <> False Then
		QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors.UseForListForm = TRUE)", "");
	EndIf;
	
	If CommandTypes = Undefined Then
		QueryText = StrReplace(QueryText, "AND (CommandsTable.StartupOption IN (&CommandTypes))", "");
	Else
		Query.SetParameter("CommandTypes", CommandTypes);
	EndIf;
	
	Query.SetParameter("Kind", DataProcessorsKind);
	If AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		QueryText = StrReplace(QueryText, "Publication = &Publication", "Publication <> &Publication");
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Else
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	EndIf;
	Query.SetParameter("CurrentUser", UsersClientServer.AuthorizedUser());
	Query.Text = QueryText;
	
	If DeepIntegrationWithSubsystemInSaaSIsUsed() Then
		AdoptQueryOfAvailableCommandsForSaaSMode(Query);
	Else
		Query.Text = StrReplace(Query.Text, "INTO SummaryTable", "");
		Query.Text = Query.Text + "
		|
		|ORDER BY
		|	Presentation";
	EndIf;
	
	Return Query;
EndFunction

// Handler of attached filling command.
//
// Parameters
//   RefsArrray - Array - an array of selected object references, for which the command is running.
//   ExecutionParameters - Structure - a command context.
//       * CommandDetails - Structure - information about the running command.
//          ** ID - String - a command ID.
//          ** Presentation - String - a command presentation on a form.
//          ** Name - String - a command name on a form.
//       * Form - ClientApplicationForm - a form the command is called from.
//       * Source - FormDataStructure, FormTable - an object or a form list with the Reference field.
//
Procedure PopulateCommandHandler(Val RefsArray, Val ExecutionParameters) Export
	CommandToExecute = ExecutionParameters.CommandDetails.AdditionalParameters;
	
	ExternalObject = ExternalDataProcessorObject(CommandToExecute.Ref);
	
	CommandParameters = New Structure;
	CommandParameters.Insert("ThisForm", ExecutionParameters.Form);
	CommandParameters.Insert("AdditionalDataProcessorRef", CommandToExecute.Ref);
	
	ExecuteExternalObjectCommand(ExternalObject, CommandToExecute.ID, CommandParameters, Undefined);
EndProcedure

Function AdditionalReportsAndDataProcessorsAreUsed() Export
	Return GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Delete subsystems references before their deletion.
Procedure BeforeDeleteMetadataObjectID(MOIDObject, Cancel) Export
	If MOIDObject.DataExchange.Load Then
		Return;
	EndIf;
	
	MOIDRef = MOIDObject.Ref;
	
	QueryText =
	"SELECT DISTINCT
	|	ReportAndDataProcessorSections.Ref
	|INTO ttRefs
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Sections AS ReportAndDataProcessorSections
	|WHERE
	|	ReportAndDataProcessorSections.Section = &MOIDRef
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ReportAndDataProcessorSections.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS ReportAndDataProcessorSections
	|WHERE
	|	ReportAndDataProcessorSections.RelatedObject = &MOIDRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ttRefs.Ref
	|FROM
	|	ttRefs AS ttRefs";
	
	Query = New Query;
	Query.SetParameter("MOIDRef", MOIDRef);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CatalogObject = Selection.Ref.GetObject();
		
		FoundItems = CatalogObject.Sections.FindRows(New Structure("Section", MOIDRef));
		For Each TableRow In FoundItems Do
			CatalogObject.Sections.Delete(TableRow);
		EndDo;
		
		FoundItems = CatalogObject.Purpose.FindRows(New Structure("RelatedObject", MOIDRef));
		For Each TableRow In FoundItems Do
			CatalogObject.Purpose.Delete(TableRow);
		EndDo;
		
		CatalogObject.Write();
	EndDo;
EndProcedure

// Updates reports and data processors in catalog from common templates.
//
// Parameters:
//   ReportsAndDataProcessors - ValueTable - a table of reports and data processors in common templates.
//       * MetadataObject - MetadataObject - a report or a data processor from the configuration.
//       * OldObjectsNames - Array - old names of objects used while searching for old versions of the report or data processor.
//           ** String - old name of the object.
//       * OldFilesNames - Array - old names of files used while searching for old versions of the report or data processor.
//           ** String - old name of the file.
//
Procedure ImportAdditionalReportsAndDataProcessorsFromMetadata(ReportsAndDataProcessors) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	MapConfigurationDataProcessorsWithCatalogDataProcessors(ReportsAndDataProcessors);
	If ReportsAndDataProcessors.Count() = 0 Then
		Return; // The update is not required.
	EndIf;
	
	ExportReportsAndDataProcessorsToFiles(ReportsAndDataProcessors);
	If ReportsAndDataProcessors.Count() = 0 Then
		Return; // Export failed.
	EndIf;
	
	RegisterReportsAndDataProcessors(ReportsAndDataProcessors);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.7.1";
	Handler.Procedure = "AdditionalReportsAndDataProcessors.UpdateDataProcessorUserAccessSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.4";
	Handler.Procedure = "AdditionalReportsAndDataProcessors.FillObjectNames";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.2";
	Handler.Procedure = "AdditionalReportsAndDataProcessors.ReplaceMetadataObjectNamesWithReferences";
	
	If NOT Common.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.ExecuteInMandatoryGroup = True;
		Handler.SharedData                  = True;
		Handler.HandlerManagement      = False;
		Handler.ExclusiveMode             = True;
		Handler.Version    = "2.1.3.22";
		Handler.Procedure = "AdditionalReportsAndDataProcessors.EnableFunctionalOption";
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.25";
	Handler.Procedure = "AdditionalReportsAndDataProcessors.FillPermissionCompatibilityMode";
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(
		Total, "2.3.3.3", "Role.AdditionalReportsAndDataProcessorsUsage", "Role.ReadAdditionalReportsAndDataProcessors", Library);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetAdditionalDataProcessor(DataItem, GetItem);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetAdditionalDataProcessor(DataItem, GetItem);
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	If Common.DataSeparationEnabled()
		Or Not AccessRight("Edit", Metadata.Catalogs.AdditionalReportsAndDataProcessors)
		Or Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If ModuleToDoListServer.UserTaskDisabled("AdditionalReportsAndDataProcessors") Then
		Return; // The to-do is disabled in the overridable module.
	EndIf;
	
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem = Undefined
		Or Not AccessRight("View", Subsystem)
		Or Not Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Sections = ModuleToDoListServer.SectionsForObject("Catalog.AdditionalReportsAndDataProcessors");
	Else
		Sections = New Array;
		Sections.Add(Subsystem);
	EndIf;
	
	OutputUserTask = True;
	VersionChecked = CommonSettingsStorage.Load("ToDoList", "AdditionalReportsAndDataProcessors");
	If VersionChecked <> Undefined Then
		ArrayVersion  = StrSplit(Metadata.Version, ".", True);
		CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
		If VersionChecked = CurrentVersion Then
			OutputUserTask = False; // Additional reports and data processors were checked on the current version.
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT AdditionalReportsAndDataProcessors.Ref) AS Count
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|	AND AdditionalReportsAndDataProcessors.DeletionMark = FALSE
	|	AND AdditionalReportsAndDataProcessors.IsFolder = FALSE";
	Count = Query.Execute().Unload()[0].Count;
	
	For Each Section In Sections Do
		SectionID = "CheckCompatibilityWithCurrentVersion" + StrReplace(Section.FullName(), ".", "");
		
		UserTask = ToDoList.Add();
		UserTask.ID = "AdditionalReportsAndDataProcessors";
		UserTask.HasUserTasks      = OutputUserTask AND Count > 0;
		UserTask.Presentation = NStr("ru = 'Дополнительные отчеты и обработки'; en = 'Additional reports and data processors'; pl = 'Dodatkowe raporty i procesory danych';es_ES = 'Informes adicionales y procesadores de datos';es_CO = 'Informes adicionales y procesadores de datos';tr = 'Ek raporlar ve veri işlemcileri';it = 'Ulteriori report e processori di dati ';de = 'Zusätzliche Berichte und Datenverarbeiter'");
		UserTask.Count    = Count;
		UserTask.Form         = "Catalog.AdditionalReportsAndDataProcessors.Form.AdditionalReportsAndDataProcessorsCheck";
		UserTask.Owner      = SectionID;
		
		// Checking whether the to-do group exists. If a group is missing, add it.
		UserTaskGroup = ToDoList.Find(SectionID, "ID");
		If UserTaskGroup = Undefined Then
			UserTaskGroup = ToDoList.Add();
			UserTaskGroup.ID = SectionID;
			UserTaskGroup.HasUserTasks      = UserTask.HasUserTasks;
			UserTaskGroup.Presentation = NStr("ru = 'Проверить совместимость'; en = 'Check compatibility'; pl = 'Kontrola zgodności';es_ES = 'Revisar la compatibilidad';es_CO = 'Revisar la compatibilidad';tr = 'Uygunluğu kontrol et';it = 'Verificare la compatibilità';de = 'Überprüfen Sie die Kompatibilität'");
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTask.Count;
			EndIf;
			UserTaskGroup.Owner = Section;
		Else
			If Not UserTaskGroup.HasUserTasks Then
				UserTaskGroup.HasUserTasks = UserTask.HasUserTasks;
			EndIf;
			
			If UserTask.HasUserTasks Then
				UserTaskGroup.Count = UserTaskGroup.Count + UserTask.Count;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalReportsAndDataProcessors";
	AccessKind.Presentation = NStr("ru = 'Дополнительные отчеты и обработки'; en = 'Additional reports and data processors'; pl = 'Dodatkowe raporty i procesory danych';es_ES = 'Informes adicionales y procesadores de datos';es_CO = 'Informes adicionales y procesadores de datos';tr = 'Ek raporlar ve veri işlemcileri';it = 'Ulteriori report e processori di dati ';de = 'Zusätzliche Berichte und Datenverarbeiter'");
	AccessKind.ValuesType   = Type("CatalogRef.AdditionalReportsAndDataProcessors");
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage. 
Procedure OnFillAccessKindUsage(AccessKind, Usage) Export
	
	SetPrivilegedMode(True);
	
	If AccessKind = "AdditionalReportsAndDataProcessors" Then
		Usage = Constants.UseAdditionalReportsAndDataProcessors.Get();
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	If NOT Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	If ModuleAccessManagementInternal.AccessKindExists("AdditionalReportsAndDataProcessors") Then
		
		Details = Details + "
		|
		|Catalog.AdditionalReportsAndDataProcessors.Read.AdditionalReportsAndDataProcessors
		|";
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadAdditionalReportsAndDataProcessors.Name);
	
EndProcedure

// See UsersOverridable.OnGetOtherSettings. 
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	// Gets additional report and data processor settings for a specified user.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors")
		Or Not AccessRight("Update", Metadata.InformationRegisters.DataProcessorAccessUserSettings) Then
		Return;
	EndIf;
	
	// Settings string name to be displayed in the data processor settings tree.
	SettingName = NStr("ru = 'Настройки быстрого доступа к дополнительным отчетам и обработкам'; en = 'Quick access settings for additional reports and data processors'; pl = 'Ustawienia szybkiego dostępu dla dodatkowych sprawozdań i przetwarzania danych';es_ES = 'Configuraciones del acceso rápido para los informes adicionales y los procesadores de datos';es_CO = 'Configuraciones del acceso rápido para los informes adicionales y los procesadores de datos';tr = 'Ek raporlara ve veri işlemcilerine hızlı erişim ayarları';it = 'Impostazioni di accesso rapido per report ed elaboratori dati aggiuntivi';de = 'Einstellungen für den Schnellzugriff auf zusätzliche Berichte und Datenprozessoren'");
	
	// Settings string picture
	PictureSettings = "";
	
	// List of additional reports and data processors the user can quickly access.
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DataProcessorAccessUserSettings.AdditionalReportOrDataProcessor AS Object,
	|	DataProcessorAccessUserSettings.CommandID AS ID,
	|	DataProcessorAccessUserSettings.User AS User
	|FROM
	|	InformationRegister.DataProcessorAccessUserSettings AS DataProcessorAccessUserSettings
	|WHERE
	|	User = &User";
	
	Query.Parameters.Insert("User", UserInfo.UserRef);
	
	QueryResult = Query.Execute().Unload();
	
	QuickAccessSettingsItem = New Structure;
	QuickAccessSettingsItem.Insert("SettingName", SettingName);
	QuickAccessSettingsItem.Insert("PictureSettings", PictureSettings);
	QuickAccessSettingsItem.Insert("SettingsList",    QueryResult);
	
	Settings.Insert("QuickAccessSetting", QuickAccessSettingsItem);
	
EndProcedure

// See UsersOverridable.OnSaveOtherSetings. 
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	// Saves additional report and data processor commands for the specified users.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	If Settings.SettingID <> "QuickAccessSetting" Then
		Return;
	EndIf;
	
	For Each RowItem In Settings.SettingValue Do
		
		Record = InformationRegisters.DataProcessorAccessUserSettings.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = RowItem.Value;
		Record.CommandID             = RowItem.Presentation;
		Record.User                     = UserInfo.UserRef;
		Record.Available                         = True;
		
		Record.Write(True);
		
	EndDo;
	
EndProcedure

// See UsersOverridable.OnDeleteOtherSettings. 
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	// Clears additional report and data processor commands for the specified user.
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	If Settings.SettingID <> "QuickAccessSetting" Then
		Return;
	EndIf;
	
	For Each RowItem In Settings.SettingValue Do
		
		Record = InformationRegisters.DataProcessorAccessUserSettings.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = RowItem.Value;
		Record.CommandID             = RowItem.Presentation;
		Record.User                     = UserInfo.UserRef;
		
		Record.Read();
		
		Record.Delete();
		
	EndDo;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds. 
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	If AttachableCommandsKinds.Find("ObjectsFilling", "Name") = Undefined Then
		Kind = AttachableCommandsKinds.Add();
		Kind.Name         = "ObjectsFilling";
		Kind.SubmenuName  = "FillSubmenu";
		Kind.Title   = NStr("ru = 'Заполнить'; en = 'Fill in'; pl = 'Wypełnij';es_ES = 'Rellenar';es_CO = 'Rellenar';tr = 'Doldur';it = 'Compila';de = 'Ausfüllen'");
		Kind.Picture    = PictureLib.FillForm;
		Kind.Representation = ButtonRepresentation.Picture;
	EndIf;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject. 
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	If Not AccessRight("Read", Metadata.InformationRegisters.AdditionalDataProcessorsPurposes) Then 
		Return;
	EndIf;
	
	If FormSettings.IsObjectForm Then
		FormType = AdditionalReportsAndDataProcessorsClientServer.ObjectFormType();
	Else
		FormType = AdditionalReportsAndDataProcessorsClientServer.ListFormType();
	EndIf;
	
	SetFOParameters = (Metadata.CommonCommands.Find("RelatedObjectsCreation") <> Undefined);
	If SetFOParameters Then
		FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsRelatedObject", Catalogs.MetadataObjectIDs.EmptyRef());
		FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsFormType",         FormType);
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	MOIDs = New Array;
	QuickSearchByMOIDs = New Map;
	For Each Source In Sources.Rows Do
		For Each DocumentRecorder In Source.Rows Do
			MOIDs.Add(DocumentRecorder.MetadataRef);
			QuickSearchByMOIDs.Insert(DocumentRecorder.MetadataRef, DocumentRecorder);
		EndDo;
		MOIDs.Add(Source.MetadataRef);
		QuickSearchByMOIDs.Insert(Source.MetadataRef, Source);
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Purpose.RelatedObject,
	|	Purpose.UseObjectFilling AS UseObjectFilling,
	|	Purpose.UseReports AS UseReports,
	|	Purpose.UseRelatedObjectCreation AS UseRelatedObjectCreation
	|FROM
	|	InformationRegister.AdditionalDataProcessorsPurposes AS Purpose
	|WHERE
	|	Purpose.RelatedObject IN(&MOIDs)
	|	AND Purpose.FormType = &FormType";
	Query.SetParameter("MOIDs", MOIDs);
	If FormType = Undefined Then
		Query.Text = StrReplace(Query.Text, "AND Purpose.FormType = &FormType", "");
	Else
		Query.SetParameter("FormType", FormType);
	EndIf;
	
	ObjectFillingTypes = New Array;
	ReportTypes = New Array;
	RelatedObjectCreationTypes = New Array;
	
	RegisterTable = Query.Execute().Unload();
	For Each TableRow In RegisterTable Do
		Source = QuickSearchByMOIDs[TableRow.RelatedObject];
		If Source = Undefined Then
			Continue;
		EndIf;
		If TableRow.UseObjectFilling Then
			AttachableCommands.SupplyTypesArray(ObjectFillingTypes, Source.DataRefType);
		EndIf;
		If TableRow.UseReports Then
			AttachableCommands.SupplyTypesArray(ReportTypes, Source.DataRefType);
		EndIf;
		If TableRow.UseRelatedObjectCreation Then
			AttachableCommands.SupplyTypesArray(RelatedObjectCreationTypes, Source.DataRefType);
		EndIf;
	EndDo;
	
	If ObjectFillingTypes.Count() > 0 Then
		Command = Commands.Add();
		If Common.SubsystemExists("StandardSubsystems.ObjectsFilling") Then
			Command.Kind           = "ObjectsFilling";
			Command.Presentation = NStr("ru = 'Дополнительные обработки заполнения...'; en = 'Additional data processors of filling in...'; pl = 'Dodatkowe procesory danych wypełnienia...';es_ES = 'Procesamientos adicionales de relleno...';es_CO = 'Procesamientos adicionales de relleno...';tr = 'Doldurulmanın ek veri işlemcileri...';it = 'Elaboratori dati aggiuntivi di compilazione...';de = 'Zusätzliche Verarbeitungen ausfüllen...'");
			Command.Importance      = "SeeAlso";
		Else
			Command.Kind           = "CommandBar";
			Command.Presentation = NStr("ru = 'Заполнение...'; en = 'Filling...'; pl = 'Wypełnienie';es_ES = 'Rellenar...';es_CO = 'Rellenar...';tr = 'Dolgu...';it = 'Riempimento...';de = 'Füllung...'");
		EndIf;
		Command.ChangesSelectedObjects = True;
		Command.Order            = 50;
		Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
		Command.WriteMode        = "Write";
		Command.MultipleChoice = True;
		Command.ParameterType       = New TypeDescription(ObjectFillingTypes);
		Command.AdditionalParameters = New Structure("Kind, IsReport", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling(), False);
	ElsIf FormSettings.IsObjectForm Then
		OnDetermineFillingCommandsAttachedToObject(Commands, MOIDs, QuickSearchByMOIDs);
	EndIf;
	
	If ReportTypes.Count() > 0 Then
		Command = Commands.Add();
		If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
			Command.Kind           = "Reports";
			Command.Importance      = "SeeAlso";
			Command.Presentation = NStr("ru = 'Дополнительные отчеты...'; en = 'Additional reports...'; pl = 'Sprawozdania dodatkowe...';es_ES = 'Informes adicionales...';es_CO = 'Informes adicionales...';tr = 'Ek raporlar...';it = 'Reports aggiuntivi...';de = 'Zusätzliche Berichte...'");
		Else
			Command.Kind           = "CommandBar";
			Command.Presentation = NStr("ru = 'Отчеты...'; en = 'Reports...'; pl = 'Raporty…';es_ES = 'Informes...';es_CO = 'Informes...';tr = 'Raporlar ...';it = 'Reports';de = 'Berichte...'");
		EndIf;
		Command.Order            = 50;
		Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
		Command.WriteMode        = "Write";
		Command.MultipleChoice = True;
		Command.ParameterType       = New TypeDescription(ReportTypes);
		Command.AdditionalParameters = New Structure("Kind, IsReport", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport(), True);
	EndIf;
	
	If RelatedObjectCreationTypes.Count() > 0 Then
		If SetFOParameters AND MOIDs.Count() = 1 Then
			FormSettings.FunctionalOptions.Insert("AdditionalReportsAndDataProcessorsRelatedObject", MOIDs[0]);
		Else
			Command = Commands.Add();
			Command.Kind                = ?(SetFOParameters, "CommandBar", "CreationBasedOn");
			Command.Presentation      = NStr("ru = 'Создание связанных объектов...'; en = 'Creation of related objects...'; pl = 'Utworzenie powiązanych obiektów...';es_ES = 'Creando objetos vinculados...';es_CO = 'Creando objetos vinculados...';tr = 'Bağlantılı nesneler oluşturuluyor ...';it = 'Creazione degli oggetti relativi...';de = 'Verknüpfte Objekte erstellen...'");
			Command.Picture           = PictureLib.InputOnBasis;
			Command.Order            = 50;
			Command.Handler         = "AdditionalReportsAndDataProcessorsClient.OpenCommandList";
			Command.WriteMode        = "Write";
			Command.MultipleChoice = True;
			Command.ParameterType       = New TypeDescription(RelatedObjectCreationTypes);
			Command.AdditionalParameters = New Structure("Kind, IsReport", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation(), False);
		EndIf;
	EndIf;
	
EndProcedure

// Adds the reports of subsystem Additional reports and data processors whose object modules contain 
//   procedure DefineFormSettings().
//
// Parameters:
//   ReportsWithSettings - Array - references of the reports whose object modules contain procedure DefineFormSettings().
//
// Usage locations:
//   ReportOptionsCached.Parameters().
//
Procedure OnDetermineReportsWithSettings(ReportsWithSettings) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If NOT AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.UseOptionStorage
	|	AND AdditionalReportsAndDataProcessors.DeepIntegrationWithReportForm
	|	AND NOT AdditionalReportsAndDataProcessors.DeletionMark
	|	AND AdditionalReportsAndDataProcessors.Kind IN(&ReportKinds)";
	ReportKinds = New Array;
	ReportKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	ReportKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("ReportKinds", ReportKinds);
	SetPrivilegedMode(True);
	AdditionalReportsWithSettings = Query.Execute().Unload().UnloadColumn("Ref");
	For Each Ref In AdditionalReportsWithSettings Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(Ref) Then
			Continue;
		EndIf;
		ReportsWithSettings.Add(Ref);
	EndDo;
EndProcedure

// Gets an additional report reference, provided that the report is attached to the "Report options" subsystem storage.
//
// Parameters:
//   ReportInformation - Structure - see ReportOptions.GenerateReportInformationByFullName(). 
//
Procedure OnDetermineTypeAndReferenceIfReportIsAuxiliary(ReportInformation) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.ObjectName = &ObjectName
	|	AND AdditionalReportsAndDataProcessors.DeletionMark = FALSE
	|	AND AdditionalReportsAndDataProcessors.UseOptionStorage = TRUE
	|	AND AdditionalReportsAndDataProcessors.Kind IN (&KindAdditionalReport, &ReportKind)
	|	AND AdditionalReportsAndDataProcessors.Publication = &PublicationUsed";
	If ReportInformation.ByDefaultAllConnectedToStorage Then
		Query.Text = StrReplace(Query.Text, "AND AdditionalReportsAndDataProcessors.UseOptionStorage = TRUE", "");
	EndIf;
	Query.SetParameter("ObjectName", ReportInformation.ReportName);
	Query.SetParameter("ReportKind",               Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindAdditionalReport", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	Query.SetParameter("PublicationUsed", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	
	// Required to ensure integrity of the generated data. Access rights will be applied during the data usage phase.
	RefsArray = Query.Execute().Unload().UnloadColumn("Ref");
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	For Each Ref In RefsArray Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(Ref) Then
			Continue;
		EndIf;
		ReportInformation.Report = Ref;
	EndDo;
	
EndProcedure

// Supplements the array with references to additional reports the current user can access.
//
// Parameters:
//   Result - Array of <see Catalogs.ReportOptions.Attributes.Report> -
//       references to the reports the current user can access.
//
// Usage locations:
//   ReportOptions.CurrentUserReports().
//
Procedure OnAddAdditionalReportsAvailableForCurrentUser(AvailableReports) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.UseOptionStorage
	|	AND AdditionalReportsAndDataProcessors.Kind IN (&KindAdditionalReport, &ReportKind)
	|	AND NOT AdditionalReportsAndDataProcessors.Ref IN (&AvailableReports)";
	
	Query.SetParameter("AvailableReports", AvailableReports);
	Query.SetParameter("ReportKind",               Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindAdditionalReport", Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(Selection.Ref) Then
			Continue;
		EndIf;
		AvailableReports.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Attaches a report from the "Additional reports and data processors" subsystem.
//   Exception handling is performed by the control script.
//
// Parameters:
//   Reference - CatalogRef.AdditionalReportsAndDataProcessors - a report to initialize.
//   ReportParameters - Structure - a set of parameters obtained while checking and attaching the report.
//       See ReportDistribution.InitializeReport(). 
//   Result - Boolean, Undefined - result of attachment.
//       True - additional report is attached.
//       False - failed to attach the additional report.
//
// Usage locations:
//   ReportsOptions.AttachReportObject().
//   ReportMailing.InitReport().
//
Procedure OnAttachAdditionalReport(Ref, ReportParameters, Result, GetMetadata) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		ReportParameters.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Элемент ""%1"" не подключен, потому что подсистема ""%2"" отключена в настройках программы.
			|Для включения подсистемы обратитесь к администратору программы.'; 
			|en = 'Item ""%1"" is not attached as subsystem ""%2"" is disabled in the application settings. 
			|To enable the subsystem, contact the application administrator.'; 
			|pl = 'Element ""%1"" nie jest podłączony, ponieważ podsystem ""%2"" jest odłączony w ustawieniach programu.
			|W celu włączenia podsystemu zwróć się do administratora programu.';
			|es_ES = 'El elemento ""%1"" no está conectado porque el subsistema ""%2"" está desactivado en los ajustes del programa.
			|Para activar el subsistema diríjase al administrador del programa.';
			|es_CO = 'El elemento ""%1"" no está conectado porque el subsistema ""%2"" está desactivado en los ajustes del programa.
			|Para activar el subsistema diríjase al administrador del programa.';
			|tr = 'Alt sistem ""%1""program ayarlarında devre dışı bırakıldığı için ""%2"" öğesi bağlı değildir. 
			|Alt sistemi etkinleştirmek için program yöneticinize başvurun.';
			|it = 'L''elemento ""%1"" non è allegato poiché il sotto sistema ""%2"" è disattivato nelle impostazioni dell''applicazione. 
			|Per attivare il sotto sistema, contattare l''amministratore dell''applicazione.';
			|de = 'Das Element ""%1"" ist nicht verbunden, da das Subsystem ""%2"" in den Programmeinstellungen deaktiviert ist.
			|Um das Subsystem zu aktivieren, wenden Sie sich an den Programmadministrator.'"),
			"'"+ String(Ref) +"'",
			AdditionalReportsAndDataProcessorsClientServer.SubsystemDescription(True));
		Return;
	EndIf;
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		OR Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Try
			ReportParameters.Name = AttachExternalDataProcessor(Ref);
			ReportParameters.Object = ExternalReports.Create(ReportParameters.Name);
			If GetMetadata Then
				ReportParameters.Metadata = ReportParameters.Object.Metadata();
			EndIf;
			Result = True;
		Except
			ReportParameters.ErrorText = 
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'При подключении дополнительного отчета ""%1"" возникла ошибка:'; en = 'An error occurred while attaching additional report ""%1"":'; pl = 'Wystąpił błąd podczas łączenia dodatkowego sprawozdania ""%1"":';es_ES = 'Ha ocurrido un error al conectar el informe adicional ""%1"":';es_CO = 'Ha ocurrido un error al conectar el informe adicional ""%1"":';tr = '""%1"" ek rapor bağlanırken bir hata oluştu:';it = 'Durante la connessione del report aggiuntivo ""%1"" si è verificato un errore:';de = 'Beim Verbinden des zusätzlichen Berichts ""%1"" ist ein Fehler aufgetreten:'"), String(Ref))
				+ Chars.LF + DetailErrorDescription(ErrorInfo());
			Result = False;
		EndTry;
		
	Else
		
		ReportParameters.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Элемент %1 не является дополнительным отчетом'; en = 'Item %1 is not an additional report'; pl = 'Element %1nie jest dodatkowym sprawozdaniem';es_ES = 'Artículo %1 no es un informe adicional';es_CO = 'Artículo %1 no es un informe adicional';tr = 'Öğe %1 ek bir rapor değildir';it = 'Elemento %1 non è una report supplementare';de = 'Artikel %1 ist kein zusätzlicher Bericht'"),
			"'"+ String(Ref) +"'");
		
		Result = False;
		
	EndIf;
	
EndProcedure

// Attaches a report from the "Additional reports and data processors" subsystem.
//   Exception handling is performed by the control script.
//
// Parameters:
//   Context - Structure - a set of parameters obtained while checking and attaching the report.
//       See ReportsOptions.OnAttachReport(). 
//
// Usage locations:
//   ReportsOptions.OnAttachReport().
//
Procedure OnAttachReport(Context) Export
	Ref = CommonClientServer.StructureProperty(Context, "Report");
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'В процедуру ""%1"" не передан отчет'; en = 'Report is not passed to the ""%1"" procedure'; pl = 'Do procedury ""%1"" nie przekazano sprawozdania';es_ES = 'No se ha enviado el informe al procedimiento ""%1""';es_CO = 'No se ha enviado el informe al procedimiento ""%1""';tr = '""%1"" prosedürüne rapor verilmedi';it = 'Report non trasmesso alla procedura ""%1""';de = 'Es wurde kein Bericht an die Prozedur ""%1"" gesendet'"),
			"AdditionalReportsAndDataProcessors.OnAttachReport");
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Функциональная опция ""%2"" отключена в настройках программы.
			|Обратитесь к администратору программы.'; 
			|en = 'The ""%2"" functional option is disabled in the application settings.
			|Contact application administrator.'; 
			|pl = 'Opcja funkcjonalna ""%2"" jest odłączona w ustawieniach programu.
			|Zwróć się do administratora programu.';
			|es_ES = 'La opción funcional ""%2"" está desactivada en los ajustes del programa.
			|Diríjase al administrador del programa.';
			|es_CO = 'La opción funcional ""%2"" está desactivada en los ajustes del programa.
			|Diríjase al administrador del programa.';
			|tr = 'Fonksiyonel seçenek ""%2"" program ayarlarında devre dışı bırakılır. 
			|Program yöneticinize başvurun.';
			|it = 'L''opzione funzionale ""%2"" è disattivata nelle impostazioni di applicazione.
			|Contattare l''amministratore di applicazione.';
			|de = 'Die Funktionsoption ""%2"" ist in den Programmeinstellungen deaktiviert.
			|Wenden Sie sich an den Programmadministrator.'"),
			AdditionalReportsAndDataProcessorsClientServer.SubsystemDescription(True));
	EndIf;
	
	Kind = Common.ObjectAttributeValue(Ref, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Context.ReportName = AttachExternalDataProcessor(Ref);
		Context.Connected = True;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Объект ""%1"" не является дополнительным отчетом'; en = 'Object ""%1"" is not an additional report'; pl = 'Obiekt ""%1"" nie jest sprawozdaniem dodatkowym';es_ES = 'El objeto ""%1"" no es un informe adicional';es_CO = 'El objeto ""%1"" no es un informe adicional';tr = 'Öğe %1 ek bir rapor değildir';it = 'L''oggetto ""%1"" non è un report aggiuntivo';de = 'Das Objekt ""%1"" ist kein zusätzlicher Bericht'"), String(Ref));
	EndIf;
	
EndProcedure

Procedure OnDetermineReportsAvailability(AdditionalReportsReferences, Result) Export
	SubsystemActive = True;
	HasReadRight = True;
	ModuleAdditionalReportsAndDataProcessorsSaaS = Undefined;
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		SubsystemActive = False;
	ElsIf Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		HasReadRight = False;
	ElsIf DeepIntegrationWithSubsystemInSaaSIsUsed() Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	
	For Each Report In AdditionalReportsReferences Do
		ReportIsAvailableInSaaS = True;
		If ModuleAdditionalReportsAndDataProcessorsSaaS <> Undefined
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(Report) Then
			ReportIsAvailableInSaaS = False;
		EndIf;
		FoundItems = Result.FindRows(New Structure("Report", Report));
		For Each TableRow In FoundItems Do
			If Not SubsystemActive Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Отчет ""%1"" недоступен, т.к. дополнительные отчеты и обработки отключены в настройках программы.'; en = '<Report ""%1"" is unavailable as additional reports and data processors are disabled in the application settings.'; pl = '<Sprawozdanie ""%1"" jest niedostępne, ponieważ sprawozdania dodatkowe i przetwarzania są odłączone w ustawieniach programu.';es_ES = '<El informe ""%1"" no está disponible porque los informes adicionales y los procesamientos están desactivados en los ajustes del programa.';es_CO = '<El informe ""%1"" no está disponible porque los informes adicionales y los procesamientos están desactivados en los ajustes del programa.';tr = '< Rapor ""%1"" kullanılamaz, çünkü ek raporlar ve işlemler program ayarlarında devre dışı bırakıldı.';it = '<Il report ""%1"" non è accessibile perché report e elaborazioni aggiuntivi sono stati disattivati nelle impostazioni del programma.';de = '<Bericht ""%1"" ist nicht verfügbar, da zusätzliche Berichte und Verarbeitungen in den Programmeinstellungen deaktiviert sind.'"),
					TableRow.Presentation);
			ElsIf Not HasReadRight Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Отчет ""%1"" недоступен, т.к. отсутствует право чтения дополнительных отчетов и обработок.'; en = '<Report ""%1"" is unavailable as you do not have the rights to read additional reports and processors.'; pl = '<Sprawozdanie ""%1"" jest niedostępne, ponieważ brak uprawnień do odczytu dodatkowych sprawozdań i przetwarzań.';es_ES = '<El informe ""%1"" no está disponible porque no hay derecho de leer los informes adicionales y los procesamientos.';es_CO = '<El informe ""%1"" no está disponible porque no hay derecho de leer los informes adicionales y los procesamientos.';tr = '< Rapor ""%1"" kullanılamaz, çünkü ek raporlar ve işlemler okunamıyor.';it = '<Il report ""%1"" non è accessibile, diritti insufficienti per lettura di report e elaborazioni aggiuntivi.';de = '<Bericht ""%1"" ist nicht verfügbar, da es kein Recht gibt, zusätzliche Berichte und Verarbeitungen zu lesen.'"),
					TableRow.Presentation);
			ElsIf Not ReportIsAvailableInSaaS Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '<Отчет ""%1"" недоступен в модели сервиса.'; en = '<Report ""%1"" is unavailable in SaaS mode.'; pl = '<Raport ""%1"" jest niedostępny w trybie SaaS.';es_ES = '<Informe ""%1"" no está disponible en el modo SaaS.';es_CO = '<Informe ""%1"" no está disponible en el modo SaaS.';tr = '<Rapor ""%1"", SaaS modunda kullanılamıyor.';it = '<Report ""%1"" non disponibile in modalità SaaS.';de = '<Bericht ""%1"" ist im SaaS-Modus nicht verfügbar.'"),
					TableRow.Presentation);
			Else
				TableRow.Available = True;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Adds external print forms to the print command list.
//
// Parameters:
//   PrintCommands - ValuesTable - see PrintManager.CreatePrintCommandCollection(). 
//   ObjectName    - String          - a full name of the metadata object to obtain the list of 
//                                     print commands for.
//
// Usage locations:
//   PrintManager.FormPrintCommands().
//
Procedure OnReceivePrintCommands(PrintCommands, ObjectName) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, ObjectName);
	CommandsTable = Query.Execute().Unload();
	
	If CommandsTable.Count() = 0 Then
		Return;
	EndIf;
	
	For Each TableRow In CommandsTable Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(TableRow.Ref) Then
			Continue;
		EndIf;
		PrintCommand = PrintCommands.Add();
		
		// Mandatory parameters.
		FillPropertyValues(PrintCommand, TableRow, "ID, Presentation");
		// Parameters used as subsystem IDs.
		PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors";
		
		// Additional parameters.
		PrintCommand.AdditionalParameters = New Structure("Ref, Modifier, StartupOption, ShowNotification");
		FillPropertyValues(PrintCommand.AdditionalParameters, TableRow);
	EndDo;
	
EndProcedure

// Fills a list of print forms from external sources.
//
// Parameters:
//   ExternalPrintForms - ValueList - print forms.
//       Value      - String - a print form ID.
//       Presentation - String - a print form name.
//   FullNameOfMetadataObject - String - a full name of the metadata object to obtain the list of 
//       print forms for.
//
// Usage locations:
//   PrintManager.OnReceiveExternalPrintFormList().
//
Procedure OnReceiveExternalPrintFormList(ExternalPrintForms, FullMetadataObjectName) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If NOT AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, FullMetadataObjectName);
	
	CommandsTable = Query.Execute().Unload();
	
	For Each Command In CommandsTable Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(Command.Ref) Then
			Continue;
		EndIf;
		If StrFind(Command.ID, ",") = 0 Then // Ignoring sets.
			ExternalPrintForms.Add(Command.ID, Command.Presentation);
		EndIf;
	EndDo;
	
EndProcedure

// Returns the reference to an external print form object.
//
// Usage locations:
//   PrintManager.OnReceiveExternalPrintForm().
//
Procedure OnReceiveExternalPrintForm(ID, FullMetadataObjectName, ExternalPrintFormRef) Export
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	If NOT AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm, FullMetadataObjectName);
	
	CommandsTable = Query.Execute().Unload();
	
	Command = CommandsTable.Find(ID, "ID");
	If Command <> Undefined Then 
		ExternalPrintFormRef = Command.Ref;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For calling from update handlers.

// [2.0.1] Replacing desktop names with references to sections (see the MetadataObjectIDs catalog.)
//
// Parameters:
//   SectionNamesAndIDs - Map - 
//       * Key - String - desktop (command) name specified previously in the following procedures:
//             AdditionalReportsAndDataProcessorsOverridable.GetCommonCommandsForAdditionalDataProcessors().
//             AdditionalReportsAndDataProcessorsOverridable.GetCommonCommandsForAdditionalReports().
//       * Value - MetadataObject: Subsystem - command interface section (level-one subsystem) that 
//             contains the desktop (command).
//
Procedure ReplaceSectionNamesWithIDs(SectionNamesAndIDs) Export
	DesktopID = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
	
	SectionNameArray = New Array;
	For Each KeyAndValue In SectionNamesAndIDs Do
		If KeyAndValue.Value = DesktopID Then
			SectionNamesAndIDs.Insert(KeyAndValue.Key, Catalogs.MetadataObjectIDs.EmptyRef());
		Else
			SectionNamesAndIDs.Insert(KeyAndValue.Key, Common.MetadataObjectID(KeyAndValue.Value));
		EndIf;
		SectionNameArray.Add(KeyAndValue.Key);
	EndDo;
	
	QueryText =
	"SELECT DISTINCT
	|	TabularSectionSections.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Sections AS TabularSectionSections
	|WHERE
	|	TabularSectionSections.DeleteSectionName IN (&SectionNameArray)";
	
	Query = New Query;
	Query.SetParameter("SectionNameArray", SectionNameArray);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		// Getting an object instance.
		Object = Selection.Ref.GetObject();
		
		For Each RowSection In Object.Sections Do
			IOM = SectionNamesAndIDs.Get(RowSection.DeleteSectionName);
			If IOM = Undefined Then
				Continue;
			EndIf;
			RowSection.Section = IOM;
			RowSection.DeleteSectionName = "";
		EndDo; 
		
		// Writing object
		InfobaseUpdate.WriteData(Object);
	EndDo;
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// [1.0.7.1] Procedure used to update the records on additional data processor availability.
Procedure UpdateDataProcessorUserAccessSettings() Export
	
	UsersWithAdditionalDataProcessors = UsersWithAccessToAdditionalDataProcessors();
	
	QueryText =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref AS DataProcessor,
	|	AdditionalReportAndDataProcessorCommands.ID AS ID
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportAndDataProcessorCommands
	|		ON (AdditionalReportAndDataProcessorCommands.Ref = AdditionalReportsAndDataProcessors.Ref)";
	
	Query = New Query;
	Query.Text = QueryText;
	DataProcessorsWithCommands = Query.Execute().Unload();
	
	RecordTable = New ValueTable;
	RecordTable.Columns.Add("DataProcessor",     New TypeDescription("CatalogRef.AdditionalReportsAndDataProcessors"));
	RecordTable.Columns.Add("ID", New TypeDescription("String"));
	RecordTable.Columns.Add("User",  New TypeDescription("CatalogRef.Users"));
	RecordTable.Columns.Add("Available",      New TypeDescription("Boolean"));
	
	For Each DataProcessorCommand In DataProcessorsWithCommands Do
		For Each User In UsersWithAdditionalDataProcessors Do
			NewRow = RecordTable.Add();
			NewRow.DataProcessor     = DataProcessorCommand.DataProcessor;
			NewRow.ID = DataProcessorCommand.ID;
			NewRow.User  = User;
			NewRow.Available   = True;
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref AS DataProcessor,
	|	AdditionalReportAndDataProcessorCommands.ID AS ID,
	|	Users.Ref AS User,
	|	DataProcessorAccessUserSettings.Available AS Available
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportAndDataProcessorCommands
	|		ON (AdditionalReportAndDataProcessorCommands.Ref = AdditionalReportsAndDataProcessors.Ref)
	|		INNER JOIN InformationRegister.DataProcessorAccessUserSettings AS DataProcessorAccessUserSettings
	|		ON (DataProcessorAccessUserSettings.AdditionalReportOrDataProcessor = AdditionalReportsAndDataProcessors.Ref)
	|			AND (DataProcessorAccessUserSettings.CommandID = AdditionalReportAndDataProcessorCommands.ID)
	|		INNER JOIN Catalog.Users AS Users
	|		ON (Users.Ref = DataProcessorAccessUserSettings.User)";
	
	Query = New Query;
	Query.Text = QueryText;
	PersonalAccessExceptions = Query.Execute().Unload();
	
	RowsSearch = New Structure("DataProcessor, ID, User");
	For Each PersonalAccessException In PersonalAccessExceptions Do
		FillPropertyValues(RowsSearch, PersonalAccessException);
		FoundItems = RecordTable.FindRows(RowsSearch);
		For Each TableRow In FoundItems Do
			TableRow.Available = NOT PersonalAccessException.Available; // Inverting with access exception.
		EndDo; 
	EndDo;
	
	For Each User In UsersWithAdditionalDataProcessors Do
		RecordSet = InformationRegisters.DataProcessorAccessUserSettings.CreateRecordSet();
		RecordSet.Filter.User.Set(User);
		QuickAccessRecords = RecordTable.FindRows(New Structure("User,Available", User, True));
		For Each QuickAccessRecord In QuickAccessRecords Do
			NewRecord = RecordSet.Add();
			NewRecord.AdditionalReportOrDataProcessor = QuickAccessRecord.DataProcessor;
			NewRecord.CommandID			= QuickAccessRecord.ID;
			NewRecord.User					= User;
			NewRecord.Available						= True;
		EndDo;
		InfobaseUpdate.WriteData(RecordSet);
	EndDo;
	
EndProcedure

// [2.0.1.4] Filling the ObjectName attribute (name used to register the object in the application).
//   For objects with the Use publication option, additional check for Object name uniqueness is 
//   performed. If any reports (data processors) with duplicate Object names for all items except 
//   the first one are found, Publication option is changed from Use to Debug mode.
//   
//
Procedure FillObjectNames() Export
	QueryText =
	"SELECT
	|	AdditionalReports.Ref,
	|	AdditionalReports.ObjectName,
	|	AdditionalReports.DataProcessorStorage,
	|	CASE
	|		WHEN AdditionalReports.Kind IN (&AddlReportsKinds)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsReport,
	|	CASE
	|		WHEN AdditionalReports.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS InPublication,
	|	CASE
	|		WHEN AdditionalReports.ObjectName = """"
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FillObjectNameRequired
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReports
	|WHERE
	|	AdditionalReports.IsFolder = FALSE
	|	AND NOT AdditionalReports.DataProcessorStorage IS NULL ";
	
	AddlReportsKinds = New Array;
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	
	Query = New Query;
	Query.SetParameter("AddlReportsKinds", AddlReportsKinds);
	Query.Text = QueryText;
	
	AllAdditionalReports = Query.Execute().Unload();
	
	SearchForDuplicates = New Structure("ObjectName, IsReport, InPublication");
	SearchForDuplicates.InPublication = True;
	
	// Additional reports and data processors that require filling the object name.
	AdditionalReportsToFill = AllAdditionalReports.FindRows(New Structure("FillObjectNameRequired", True));
	For Each TableRow In AdditionalReportsToFill Do
		
		// Storing the report's or data processor's binary data to a temporary storage.
		AddressInTempStorage = PutToTempStorage(TableRow.DataProcessorStorage.Get());
		
		// Defining the manager
		Manager = ?(TableRow.IsReport, ExternalReports, ExternalDataProcessors);
		
		// Getting an object instance.
		Object = TableRow.Ref.GetObject();
		
		// Setting object name
		If Common.HasUnsafeActionProtection() Then
			Object.ObjectName = TrimAll(Manager.Connect(AddressInTempStorage, , True,
				Common.ProtectionWithoutWarningsDetails()));
		Else
			Object.ObjectName = TrimAll(Manager.Connect(AddressInTempStorage, , True));
		EndIf;
		
		// If a report or data processor name is already used by another published report or data processor, 
		// the current object is a duplicate. It is necessary to set its publication option to Debug mode (or disable it).
		If TableRow.InPublication Then
			SearchForDuplicates.ObjectName = Object.ObjectName;
			SearchForDuplicates.IsReport   = TableRow.IsReport;
			If AllAdditionalReports.FindRows(SearchForDuplicates).Count() > 0 Then
				DisableConflicting(Object);
			EndIf;
		EndIf;
		
		// Recording the used object name in the duplicate control table.
		TableRow.ObjectName = Object.ObjectName;
		
		// Writing object
		InfobaseUpdate.WriteData(Object);
		
	EndDo;
	
EndProcedure

// [2.1.3.2) Replacing names of related objects with references from the MetadataObjectIDs catalog.
Procedure ReplaceMetadataObjectNamesWithReferences() Export
	
	QueryText =
	"SELECT
	|	AssignmentTable.Ref AS CatalogRef,
	|	AssignmentTable.LineNumber AS LineNumber,
	|	CatalogMOID.Ref AS RelatedObject
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AssignmentTable
	|		LEFT JOIN Catalog.MetadataObjectIDs AS CatalogMOID
	|		ON AssignmentTable.DeleteMetadataObjectFullName = CatalogMOID.FullName
	|TOTALS BY
	|	CatalogRef";
	
	Query = New Query;
	Query.Text = QueryText;
	
	ReferencesSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While ReferencesSelection.Next() Do
		CatalogObject = ReferencesSelection.CatalogRef.GetObject();
		ArrayOfRowsforDeleting = New Array;
		RowSelection = ReferencesSelection.Select();
		While RowSelection.Next() Do
			TabularSectionRow = CatalogObject.Purpose.Get(RowSelection.LineNumber - 1);
			TabularSectionRow.RelatedObject = RowSelection.RelatedObject;
			If ValueIsFilled(TabularSectionRow.RelatedObject) Then
				TabularSectionRow.DeleteMetadataObjectFullName = "";
			Else
				ArrayOfRowsforDeleting.Add(TabularSectionRow);
			EndIf;
		EndDo;
		For Each TabularSectionRow In ArrayOfRowsforDeleting Do
			CatalogObject.Purpose.Delete(TabularSectionRow);
		EndDo;
		InfobaseUpdate.WriteData(CatalogObject);
	EndDo;
	
	InformationRegisters.AdditionalDataProcessorsPurposes.Refresh(True);
	
EndProcedure

// [2.1.3.22] Enabling the UseAdditionalReportsAndDataProcessors functional option for local mode.
Procedure EnableFunctionalOption() Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Constants.UseAdditionalReportsAndDataProcessors.Set(True);
	
EndProcedure

// [2.2.2.25] Filling attribute PermissionCompatibilityMode for catalog AdditionalReportsAndDataProcessors.
Procedure FillPermissionCompatibilityMode() Export
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		Lock.Add("Catalog.AdditionalReportsAndDataProcessors");
		Lock.Lock();
		
		Selection = Catalogs.AdditionalReportsAndDataProcessors.Select();
		While Selection.Next() Do
			
			If Not Selection.IsFolder AND Not ValueIsFilled(Selection.PermissionCompatibilityMode) Then
				
				LockDataForEdit(Selection.Ref);
				
				Object = Selection.GetObject();
				
				Try
					
					ObjectToProcess = ExternalDataProcessorObject(Selection.Ref);
					RegistrationData = ObjectToProcess.ExternalDataProcessorInfo();
					
					If RegistrationData.Property("SSLVersion") Then
						If CommonClientServer.CompareVersions(RegistrationData.SSLVersion, "2.2.2.0") > 0 Then
							CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2;
						Else
							CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
						EndIf;
					Else
						CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
					EndIf;
					
					Publication = Object.Publication;
					
				Except
					
					// If it is impossible to attach the data processor, switching to permission compatibility with SL 2.
					// 1.3 and enabling a temporary lock.
					ErrorText = """" + Object.Description + """:"
						+ Chars.LF + NStr("ru = 'Не удалось определить режим совместимости разрешений по причине:'; en = 'Cannot determine the permissions compatibility mode for this reason:'; pl = 'Nie udało się określić tryb kompatybilności zezwoleń z powodu:';es_ES = 'No se ha podido determinar el modo de compatibilidad de extensiones a causa de:';es_CO = 'No se ha podido determinar el modo de compatibilidad de extensiones a causa de:';tr = 'Aşağıdaki nedenle izin uyumluluk modu belirlenemedi:';it = 'Impossibile determinare la modalità di compatibilità dei permessi a causa di:';de = 'Der Kompatibilitätsmodus der Berechtigungen konnte aus folgendem Grund nicht ermittelt werden:'")
						+ Chars.LF + DetailErrorDescription(ErrorInfo())
						+ Chars.LF
						+ Chars.LF + NStr("ru = 'Объект заблокирован в режиме совместимости с версией 2.1.3.'; en = 'The object is locked in version 2 compatibility mode1.3.'; pl = 'Obiekt jest zablokowany w trybie kompatybilności z wersją 2.1.3.';es_ES = 'El objeto está bloqueado en el modo de compatibilidad con la versión 2.1.3.';es_CO = 'El objeto está bloqueado en el modo de compatibilidad con la versión 2.1.3.';tr = 'Nesne sürüm 2.1.3 ile uyumluluk modunda kilitlendi.';it = 'L''oggetto è bloccato nella versione 2 modalità di compatibilità1.3.';de = 'Das Objekt wird im Kompatibilitätsmodus1.3 mit der Version 2 gesperrt.'");
					WriteWarning(Object.Ref, ErrorText);
					CompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
					Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
					
				EndTry;
				
				Object.PermissionCompatibilityMode = CompatibilityMode;
				Object.Publication = Publication;
				InfobaseUpdate.WriteData(Object);
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Scheduled jobs

// StartingDataProcessors scheduled job instance handler.
//   Starts a global data processor handler for the scheduled job, using the specified command ID.
//   
//
// Parameters:
//   ExternalDataProcessor - CatalogRef.AdditionalReportsAndDataProcessors - a reference to the data processor being executed.
//   CommandID - String - ID of the command being executed.
//
Procedure ExecuteDataProcessorByScheduledJob(ExternalDataProcessor, CommandID) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.StartingAdditionalDataProcessors);
	
	// Writing to the event log
	WriteInformation(ExternalDataProcessor, NStr("ru = 'Команда %1: Запуск.'; en = 'Command %1: Start.'; pl = 'Polecenie %1: Start.';es_ES = 'Comando %1: Iniciar.';es_CO = 'Comando %1: Iniciar.';tr = 'Komut%1: Başlat.';it = '%1 comando: Start.';de = 'Befehl %1: Start.'"), CommandID);
	
	// Executing the command
	Try
		ExecuteCommand(New Structure("AdditionalDataProcessorRef, CommandID", ExternalDataProcessor, CommandID), Undefined);
	Except
		WriteError(
			ExternalDataProcessor,
			NStr("ru = 'Команда %1: Ошибка выполнения:%2'; en = 'Command: %1. Runtime error:%2'; pl = 'Polecenie %1: Błąd wykonania:%2';es_ES = 'Comando %1: Error de ejecución:%2';es_CO = 'Comando %1: Error de ejecución:%2';tr = 'Komut %1: Yürütme hatası:%2';it = 'Comando %1: Errore di esecuzione: %2';de = 'Befehl %1: Ausführungsfehler: %2'"),
			CommandID,
			Chars.LF + DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Writing to the event log
	WriteInformation(ExternalDataProcessor, NStr("ru = 'Команда %1: Завершение.'; en = 'Command %1: End.'; pl = 'Polecenie %1: Zakończ.';es_ES = 'Comando %1: Final.';es_CO = 'Comando %1: Final.';tr = 'Komut %1: Son.';it = '%1 comando: Completamento.';de = 'Befehl %1: Ende.'"), CommandID);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Returns True when the specified additional report (data processor) kind is global.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportAndDataProcessorKinds - a kind of external data processor.
//
// Returns:
//    True - the data processor is global.
//    False - the data processor is assignable.
//
Function CheckGlobalDataProcessor(Kind) Export
	
	Return Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor
		Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	
EndFunction

// Transforms an additional report (data processor) kind from string constant to an enumeration reference.
//
// Parameters:
//   StringPresentation - String - a string representation of the kind.
//
// Returns:
//   EnumRef.AdditionalReportAndDataProcessorKinds - a reference to the kind.
//
Function GetDataProcessorKindByKindStringPresentation(StringPresentation) Export
	
	If StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindMessageTemplate() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	EndIf;
	
EndFunction

// Transforms an additional report (data processor) kind from an enumeration reference to a string constant.
Function KindToString(KindReference) Export
	
	If KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindRelatedObjectCreation();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.MessageTemplate Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindMessageTemplate();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport();
		
	Else
		Return "";
	EndIf;
	
EndFunction

// Returns a command desktop name.
Function SectionPresentation(Section) Export
	If Section = AdditionalReportsAndDataProcessorsClientServer.DesktopID()
		Or Section = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'");
	Else
		Return MetadataObjectPresentation(Section);
	EndIf;
EndFunction

// Returns a command desktop name.
Function MetadataObjectPresentation(Object) Export
	If TypeOf(Object) = Type("CatalogRef.MetadataObjectIDs") Then
		MetadataObject = Catalogs.MetadataObjectIDs.MetadataObjectByID(Object, True);
		If TypeOf(MetadataObject) <> Type("MetadataObject") Then
			Return Undefined;
		EndIf;
	ElsIf TypeOf(Object) = Type("MetadataObject") Then
		MetadataObject = Object;
	Else
		MetadataObject = Metadata.Subsystems.Find(Object);
	EndIf;
	Return MetadataObject.Presentation();
EndFunction

// Verifies right to add additional reports and data processors.
Function InsertRight(Val AdditionalDataProcessor = Undefined) Export
	
	Result = False;
	StandardProcessing = True;
	
	SaaSIntegration.OnCheckAddRight(AdditionalDataProcessor, Result, StandardProcessing);
	
	If StandardProcessing Then
		
		If Common.DataSeparationEnabled()
		   AND Common.SeparatedDataUsageAvailable() Then
			
			Result = Users.IsFullUser(, True);
		Else
			Result = AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors);
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether an additional report or data processor can be exported to file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//   Boolean
//
Function CanExportDataProcessorToFile(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	
	SaaSIntegration.OnCheckCanExportDataProcessorToFile(DataProcessor, Result, StandardProcessing);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	Return True;
	
EndFunction

// Checks whether an additional data processor can be imported from file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//   Boolean
//
Function CanImportDataProcessorFromFile(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	SaaSIntegration.OnCheckCanImportDataProcessorFromFile(DataProcessor, Result, StandardProcessing);
		
	If Not StandardProcessing Then
		Return Result;
	EndIf;
		
	Return True;
	
EndFunction

// Returns a flag specifying whether extended information on additional reports and data processors must be displayed to user.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors.
//
// Returns:
//   Boolean
//
Function DisplayExtendedInformation(Val DataProcessor) Export
	
	Return True;
	
EndFunction

// Publication kinds unavailable for use in the current application mode.
Function UnavailablePublicationKinds() Export
	
	Result = New Array;
	SaaSIntegration.OnFillUnavailablePublicationKinds(Result);
	Return Result;
	
EndFunction

// The procedure is called from the BeforeWrite event of the catalog.
//  AdditionalReportsAndDataProcessors. Validates changes to the directory item attributes for 
//  additional data processors retrieved from the service manager additional data processors 
//  directory.
//
// Parameters:
//   Source - CatalogObject.AdditionalReportsAndDataProcessors.
//   Cancel - Boolean - the flag specifying whether writing a catalog item must be canceled.
//
Procedure BeforeWriteAdditionalDataProcessor(Source, Cancel) Export
	
	SaaSIntegration.BeforeWriteAdditionalDataProcessor(Source, Cancel);
	
EndProcedure

// The procedure is called from the BeforeDelete event of catalog.
//  AdditionalReportsAndDataProcessors.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors.
//  Boolean - flag specifying whether catalog item deletion must be cancelled.
//
Procedure BeforeDeleteAdditionalDataProcessor(Source, Cancel) Export
	
	SaaSIntegration.BeforeDeleteAdditionalDataProcessor(Source, Cancel);
	
EndProcedure

// Determines whether filter of attached additional reports and data processors for SaaS mode is 
// used in the current session.
Function DeepIntegrationWithSubsystemInSaaSIsUsed() Export
	Return Common.DataSeparationEnabled()
		AND Common.SubsystemExists("CloudTechnology.SaaS.AdditionalReportsAndDataProcessorsSaaS");
EndFunction

// The function is called on generating a new query used to get a command table for additional reports or data processors.
Function AdoptQueryOfAvailableCommandsForSaaSMode(Query)
	RegisterName = "UseSuppliedAdditionalReportsAndProcessorsInDataAreas";
	Query.Text = Query.Text + ";
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SummaryTable.Ref,
	|	SummaryTable.ID,
	|	SummaryTable.CommandsToReplace,
	|	SummaryTable.StartupOption,
	|	SummaryTable.Presentation AS Presentation,
	|	SummaryTable.ShowNotification,
	|	SummaryTable.Modifier,
	|	SummaryTable.Use
	|FROM
	|	SummaryTable AS SummaryTable
	|		INNER JOIN &FullRegisterName AS Installations
	|		ON SummaryTable.Ref = Installations.DataProcessorBeingUsed
	|
	|ORDER BY
	|	Presentation";
	Query.Text = StrReplace(Query.Text, "&FullRegisterName", "InformationRegister." + RegisterName);
	Return True;
EndFunction

// Writing an error to event log dedicated to the additional report (data processor).
Procedure WriteError(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	Level = EventLogLevel.Error;
	WriteToLog(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Writing a warning to event log dedicated to the additional report (data processor).
Procedure WriteWarning(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined)
	Level = EventLogLevel.Warning;
	WriteToLog(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Writing information to event log dedicated to the additional report (data processor).
Procedure WriteInformation(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined)
	Level = EventLogLevel.Information;
	WriteToLog(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Writing a comment to event log dedicated to the additional report (data processor).
Procedure WriteComment(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined)
	Level = EventLogLevel.Note;
	WriteToLog(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Writing an event to event log dedicated to the additional report (data processor).
Procedure WriteToLog(Level, Ref, Text, Parameter1, Parameter2, Parameter3)
	Text = StrReplace(Text, "%1", Parameter1); // Cannot go to the StrTemplate.
	Text = StrReplace(Text, "%2", Parameter2);
	Text = StrReplace(Text, "%3", Parameter3);
	WriteLogEvent(
		AdditionalReportsAndDataProcessorsClientServer.SubsystemDescription(False),
		Level,
		Metadata.Catalogs.AdditionalReportsAndDataProcessors,
		Ref,
		Text);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// For internal use.
Function UsersWithAccessToAdditionalDataProcessors()
	
	Result = New Array;
	
	RolesBeingChecked = "ReadAdditionalReportsAndDataProcessors, AddEditAdditionalReportsAndDataProcessors";
	
	Query = New Query("SELECT Ref FROM Catalog.Users");
	AllUsers = Query.Execute().Unload().UnloadColumn("Ref");
	
	For Each User In AllUsers Do
		If Users.RolesAvailable(RolesBeingChecked, User, False) Then
			Result.Add(User);
		EndIf;
	EndDo;
	
	QueryText =
	"SELECT DISTINCT
	|	AccessSettings.User
	|FROM
	|	InformationRegister.DataProcessorAccessUserSettings AS AccessSettings
	|WHERE
	|	NOT AccessSettings.User IN (&UsersAddedEarlier)";
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("UsersAddedEarlier", Result);
	UsersInRegister = Query.Execute().Unload().UnloadColumn("User");
	
	For Each User In UsersInRegister Do
		Result.Add(User);
	EndDo;
	
	Return Result;
	
EndFunction

// For internal use.
Procedure ExecuteAdditionalReportOrDataProcessorCommand(ExternalObject, Val CommandID, CommandParameters, Val ScenarioInSafeMode = False)
	
	If ScenarioInSafeMode Then
		
		ExecuteScenarioInSafeMode(ExternalObject, CommandParameters);
		
	Else
		
		If CommandParameters = Undefined Then
			
			ExternalObject.ExecuteCommand(CommandID);
			
		Else
			
			ExternalObject.ExecuteCommand(CommandID, CommandParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecuteAssignableAdditionalReportOrDataProcessorCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects, Val ScenarioInSafeMode = False)
	
	If ScenarioInSafeMode Then
		
		ExecuteScenarioInSafeMode(ExternalObject, CommandParameters, RelatedObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.ExecuteCommand(CommandID, RelatedObjects);
		Else
			ExternalObject.ExecuteCommand(CommandID, RelatedObjects, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecuteRelatedObjectCreationCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects, ModifiedObjects, Val ScenarioInSafeMode = False)
	
	If ScenarioInSafeMode Then
		
		CommandParameters.Insert("ModifiedObjects", ModifiedObjects);
		
		ExecuteScenarioInSafeMode(ExternalObject, CommandParameters, RelatedObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.ExecuteCommand(CommandID, RelatedObjects, ModifiedObjects);
		Else
			ExternalObject.ExecuteCommand(CommandID, RelatedObjects, ModifiedObjects, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use.
Procedure ExecutePrintFormCreationCommand(ExternalObject, Val CommandID, CommandParameters, RelatedObjects, Val ScenarioInSafeMode = False)
	
	If ScenarioInSafeMode Then
		
		ExecuteScenarioInSafeMode(ExternalObject, CommandParameters, RelatedObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.Print(CommandID, RelatedObjects);
		Else
			ExternalObject.Print(CommandID, RelatedObjects, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// Executes an additional report (data processor) command from an object.
Function ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, ResultAddress)
	
	ExternalObjectInfo = ExternalObject.ExternalDataProcessorInfo();
	
	DataProcessorKind = GetDataProcessorKindByKindStringPresentation(ExternalObjectInfo.Kind);
	
	PassParameters = (
		ExternalObjectInfo.Property("SSLVersion")
		AND CommonClientServer.CompareVersions(ExternalObjectInfo.SSLVersion, "1.2.1.4") >= 0);
	
	ExecutionResult = CommonClientServer.StructureProperty(CommandParameters, "ExecutionResult");
	If TypeOf(ExecutionResult) <> Type("Structure") Then
		CommandParameters.Insert("ExecutionResult", New Structure());
	EndIf;
	
	CommandDetails = ExternalObjectInfo.Commands.Find(CommandID, "ID");
	If CommandDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Команда %1 не обнаружена.'; en = 'Command %1 is not found'; pl = 'Polecenie %1 nie znaleziono.';es_ES = 'Comando %1 no se ha encontrado.';es_CO = 'Comando %1 no se ha encontrado.';tr = 'Komut %1 bulunamadı.';it = 'Comando %1 non è stato trovato.';de = 'Befehl %1 nicht gefunden.'"), CommandID);
	EndIf;
	
	IsScenarioInSafeMode = (CommandDetails.Use = "ScenarioInSafeMode");
	
	ModifiedObjects = Undefined;
	
	If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		ExecuteAdditionalReportOrDataProcessorCommand(
			ExternalObject,
			CommandID,
			?(PassParameters, CommandParameters, Undefined),
			IsScenarioInSafeMode);
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		
		ModifiedObjects = New Array;
		ExecuteRelatedObjectCreationCommand(
			ExternalObject,
			CommandID,
			?(PassParameters, CommandParameters, Undefined),
			CommandParameters.RelatedObjects,
			ModifiedObjects,
			IsScenarioInSafeMode);
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.Report
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		
		RelatedObjects = Undefined;
		CommandParameters.Property("RelatedObjects", RelatedObjects);
		
		If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
			
			// Only arbitrary printing here. MXL printing is performed through the Print subsystem.
			ExecutePrintFormCreationCommand(
				ExternalObject,
				CommandID,
				?(PassParameters, CommandParameters, Undefined),
				RelatedObjects,
				IsScenarioInSafeMode);
			
		Else
			
			ExecuteAssignableAdditionalReportOrDataProcessorCommand(
				ExternalObject,
				CommandID,
				?(PassParameters, CommandParameters, Undefined),
				RelatedObjects,
				IsScenarioInSafeMode);
			
			If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
				ModifiedObjects = RelatedObjects;
			EndIf;
		EndIf;
		
	EndIf;
	
	CommandParameters.ExecutionResult.Insert("NotifyForms", StandardSubsystemsServer.PrepareFormChangeNotification(ModifiedObjects));
	
	If TypeOf(ResultAddress) = Type("String") AND IsTempStorageURL(ResultAddress) Then
		PutToTempStorage(CommandParameters.ExecutionResult, ResultAddress);
	EndIf;
	
	Return CommandParameters.ExecutionResult;
	
EndFunction

// For internal use.
Procedure ExecuteScenarioInSafeMode(ExternalObject, CommandParameters, RelatedObjects = Undefined)
	
	SafeModeExtension = AdditionalReportsAndDataProcessorsSafeModeInternal;
	
	ExternalObject = ExternalDataProcessorObject(CommandParameters.AdditionalDataProcessorRef);
	CommandID = CommandParameters.CommandID;
	
	Scenario = ExternalObject.GenerateScenario(CommandID, CommandParameters);
	SessionKey = AdditionalReportsAndDataProcessorsSafeModeInternal.GenerateSafeModeExtensionSessionKey(
		CommandParameters.AdditionalDataProcessorRef);
	
	SafeModeExtension.ExecuteSafeModeScenario(
		SessionKey, Scenario, ExternalObject, CommandParameters, Undefined, RelatedObjects);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures used for data exchange.

// Redefines standard behavior during data import.
// ScheduledJobGUID attribute of the Commands tabular section cannot be transferred, because it is 
// related to a scheduled job of the current infobase.
//
Procedure OnGetAdditionalDataProcessor(DataItem, GetItem)
	
	If GetItem = DataItemReceive.Ignore Then
		
		// No overriding for standard processing.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors")
		AND DataItem.Type = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		
		// Table of unique scheduled job IDs.
		QueryText =
		"SELECT
		|	Commands.Ref AS Ref,
		|	Commands.ID AS ID,
		|	Commands.GUIDScheduledJob AS GUIDScheduledJob
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS Commands
		|WHERE
		|	Commands.Ref = &Ref";
		
		Query = New Query(QueryText);
		Query.Parameters.Insert("Ref", DataItem.Ref);
		
		ScheduledJobIDs = Query.Execute().Unload();
		
		// Filling the command table with the scheduled job IDs based on the current database data.
		For Each StringCommand In DataItem.Commands Do
			FoundItems = ScheduledJobIDs.FindRows(New Structure("ID", StringCommand.ID));
			If FoundItems.Count() = 0 Then
				StringCommand.GUIDScheduledJob = New UUID("00000000-0000-0000-0000-000000000000");
			Else
				StringCommand.GUIDScheduledJob = FoundItems[0].GUIDScheduledJob;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Maps catalog items with configuration metadata objects.

Procedure MapConfigurationDataProcessorsWithCatalogDataProcessors(ReportsAndDataProcessors)
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref,
	|	AdditionalReportsAndDataProcessors.Version,
	|	AdditionalReportsAndDataProcessors.ObjectName,
	|	AdditionalReportsAndDataProcessors.FileName
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors";
	
	DataProcessorsFromConfiguration = Query.Execute().Unload();
	For Each ConfigurationDataProcessor In DataProcessorsFromConfiguration Do
		ConfigurationDataProcessor.ObjectName = Upper(ConfigurationDataProcessor.ObjectName);
		ConfigurationDataProcessor.FileName   = Upper(ConfigurationDataProcessor.FileName);
	EndDo;
	DataProcessorsFromConfiguration.Columns.Add("Found", New TypeDescription("Boolean"));
	
	ReportsAndDataProcessors.Columns.Add("Name");
	ReportsAndDataProcessors.Columns.Add("FileName");
	ReportsAndDataProcessors.Columns.Add("FullName");
	ReportsAndDataProcessors.Columns.Add("Kind");
	ReportsAndDataProcessors.Columns.Add("Extension");
	ReportsAndDataProcessors.Columns.Add("Manager");
	ReportsAndDataProcessors.Columns.Add("Information");
	ReportsAndDataProcessors.Columns.Add("DataFromCatalog");
	ReportsAndDataProcessors.Columns.Add("Ref");
	
	ReverseIndex = ReportsAndDataProcessors.Count();
	While ReverseIndex > 0 Do
		ReverseIndex = ReverseIndex - 1;
		TableRow = ReportsAndDataProcessors[ReverseIndex];
		
		TableRow.Name = TableRow.MetadataObject.Name;
		TableRow.FullName = TableRow.MetadataObject.FullName();
		TableRow.Kind = Upper(StrSplit(TableRow.FullName, ".")[0]);
		If TableRow.Kind = "REPORT" Then
			TableRow.Extension = "erf";
			ManagerFromConfigurationMetadata = Reports[TableRow.Name];
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			TableRow.Extension = "epf";
			ManagerFromConfigurationMetadata = DataProcessors[TableRow.Name];
		Else
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue; // Unsupported metadata object kind.
		EndIf;
		TableRow.FileName = TableRow.Name + "." + TableRow.Extension;
		TableRow.OldFilesNames.Insert(0, TableRow.FileName);
		TableRow.OldObjectsNames.Insert(0, TableRow.Name);
		
		TableRow.Information = ManagerFromConfigurationMetadata.Create().ExternalDataProcessorInfo();
		
		// Searching the catalog.
		DataFromCatalog = Undefined;
		For Each FileName In TableRow.OldFilesNames Do
			DataFromCatalog = DataProcessorsFromConfiguration.Find(Upper(FileName), "FileName");
			If DataFromCatalog <> Undefined Then
				Break;
			EndIf;
		EndDo;
		If DataFromCatalog = Undefined Then
			For Each ObjectName In TableRow.OldObjectsNames Do
				DataFromCatalog = DataProcessorsFromConfiguration.Find(Upper(ObjectName), "ObjectName");
				If DataFromCatalog <> Undefined Then
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If DataFromCatalog = Undefined Then
			Continue; // Registering a new data processor.
		EndIf;
		
		If VersionAsNumber(DataFromCatalog.Version) >= VersionAsNumber(TableRow.Information.Version)
			AND TableRow.Information.Version <> Metadata.Version Then
			// Update is not required because the catalog contains the latest version of the data processor.
			ReportsAndDataProcessors.Delete(ReverseIndex);
		Else
			// Registering a reference for update.
			TableRow.Ref = DataFromCatalog.Ref;
		EndIf;
		DataProcessorsFromConfiguration.Delete(DataFromCatalog);
		
	EndDo;
	
	ReportsAndDataProcessors.Columns.Delete("OldFilesNames");
	ReportsAndDataProcessors.Columns.Delete("OldObjectsNames");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exports configuration reports and data processors to the files of external reports and data processors.

Procedure ExportReportsAndDataProcessorsToFiles(ReportsAndDataProcessors)
	
	ReportsAndDataProcessors.Columns.Add("BinaryData");
	Parameters = New Structure;
	Parameters.Insert("WorkingDirectory", Common.CreateTemporaryDirectory("ARADP"));
	StartupCommand = New Array;
	StartupCommand.Add("/DumpConfigToFiles");
	StartupCommand.Add(Parameters.WorkingDirectory);
	DataExported = DesignerBatchMode(Parameters, StartupCommand);
	If Not DataExported.Success Then
		ErrorText = TrimAll(
			NStr("ru = 'Не удалось выгрузить отчеты и обработки конфигурации во внешние файлы:'; en = 'Failed to export reports and configuration data processors to external files:'; pl = 'Nie udało się przesłać sprawozdania i przetwarzania konfiguracji do plików zewnętrznych:';es_ES = 'No se ha podido subir los informes y los procesamientos de la configuración en los archivos externos:';es_CO = 'No se ha podido subir los informes y los procesamientos de la configuración en los archivos externos:';tr = 'Dış dosyalara rapor ve yapılandırma işleme yüklenemedi:';it = 'Impossibile caricare i report e le elaborazioni della configurazione su file esterni:';de = 'Berichte und Konfigurationsverarbeitung konnten nicht in externe Dateien hochgeladen werden:'")
			+ Chars.LF + DataExported.InBrief
			+ Chars.LF + DataExported.More);
		WriteWarning(Undefined, ErrorText);
		ReportsAndDataProcessors.Clear();
	EndIf;
	
	ReverseIndex = ReportsAndDataProcessors.Count();
	While ReverseIndex > 0 Do
		ReverseIndex = ReverseIndex - 1;
		TableRow = ReportsAndDataProcessors[ReverseIndex];
		
		If TableRow.Kind = "REPORT" Then
			KindDirectory = Parameters.WorkingDirectory + "Reports" + GetPathSeparator();
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			KindDirectory = Parameters.WorkingDirectory + "DataProcessors" + GetPathSeparator();
		Else
			WriteError(TableRow.Ref, NStr("ru = 'Неподдерживаемый вид объектов метаданных: ""1""'; en = 'Unsupported metadata object kind: ""1""'; pl = 'Nieobsługiwany rodzaj obiektów metadanych: ""1""';es_ES = 'Tipo de los objetos de metadatos no admitido: ""1""';es_CO = 'Tipo de los objetos de metadatos no admitido: ""1""';tr = 'Desteklenmeyen meta veri nesne görünümü: ""1""';it = 'Tipo di oggetto di metadati non supportato: ""1""';de = 'Nicht unterstützte Ansicht von Metadatenobjekten: ""1""'"), TableRow.Kind);
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		
		ObjectSchemaFullName = KindDirectory + TableRow.Name + ".xml";
		SchemaText = ReadTextFile(ObjectSchemaFullName);
		If SchemaText = Undefined Then
			WriteError(TableRow.Ref, NStr("ru = 'Не обнаружен файл ""%1"".'; en = 'The ""%1"" file is not detected.'; pl = 'Nie znaleziono pliku ""%1"".';es_ES = 'Archivo no encontrado ""%1"".';es_CO = 'Archivo no encontrado ""%1"".';tr = '""%1"" dosya bulunamadı.';it = 'File ""%1"" non rilevato.';de = 'Datei ""%1"" wurde nicht gefunden.'"), ObjectSchemaFullName);
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		If TableRow.Kind = "REPORT" Then
			SchemaText = StrReplace(SchemaText, "Report", "ExternalReport");
			SchemaText = StrReplace(SchemaText, "ExternalReportTabularSection", "ReportTabularSection");
		ElsIf TableRow.Kind = "DATAPROCESSOR" Then
			SchemaText = StrReplace(SchemaText, "DataProcessor", "ExternalDataProcessor");
		EndIf;
		WriteTextFile(ObjectSchemaFullName, SchemaText);
		
		If TableRow.Kind = "DATAPROCESSOR" Then
			DocumentDOM = ReadDOMDocument(ObjectSchemaFullName);
			Dereferencer = New DOMNamespaceResolver(DocumentDOM);
			XMLChanged = False;
			
			SearchExpressionsForNodesToDelete = New Array;
			SearchExpressionsForNodesToDelete.Add("//xmlns:Command");
			SearchExpressionsForNodesToDelete.Add("//*[contains(@name, 'ExternalDataProcessorManager.')]");
			SearchExpressionsForNodesToDelete.Add("//xmlns:UseStandardCommands");
			SearchExpressionsForNodesToDelete.Add("//xmlns:IncludeHelpInContents");
			SearchExpressionsForNodesToDelete.Add("//xmlns:ExtendedPresentation");
			SearchExpressionsForNodesToDelete.Add("//xmlns:Explanation");
			
			For Each Expression In SearchExpressionsForNodesToDelete Do
				XPathResult = EvaluateXPathExpression(Expression, DocumentDOM, Dereferencer);
				DOMItem = XPathResult.IterateNext();
				While DOMItem <> Undefined Do
					DOMItem.ParentNode.RemoveChild(DOMItem);
					XMLChanged = True;
					DOMItem = XPathResult.IterateNext();
				EndDo;
			EndDo;
			
			If XMLChanged Then
				WriteDOMDocument(DocumentDOM, ObjectSchemaFullName);
			EndIf;
		EndIf;
		
		FullFileName = Parameters.WorkingDirectory + TableRow.FileName;
		StartupCommand = New Array;
		StartupCommand.Add("/LoadExternalDataProcessorOrReportFromFiles");
		StartupCommand.Add(ObjectSchemaFullName);
		StartupCommand.Add(FullFileName);
		CreateDataProcessor = DesignerBatchMode(Parameters, StartupCommand);
		If Not CreateDataProcessor.Success Then
			ErrorText = NStr("ru = 'Не удалось создать ""%1"" из внешнего файла ""%2"":%3'; en = 'Cannot create ""%1"" from external file ""%2"":%3'; pl = 'Nie udało się utworzyć ""%1"" z pliku zewnętrznego ""%2"":%3';es_ES = 'No se ha podido crear ""%1"" del archivo externo ""%2"":%3';es_CO = 'No se ha podido crear ""%1"" del archivo externo ""%2"":%3';tr = '""%1"" harici dosyadan ""%2"" oluşturulamadı: %3';it = 'Non è stato possibile creare ""%1"" dal file esterno ""%2"":%3';de = '""%1"" konnte nicht aus der externen Datei ""%2"" erstellt werden: %3'");
			WriteWarning(Undefined, ErrorText, TableRow.FullName, ObjectSchemaFullName, Chars.LF + TrimAll(CreateDataProcessor.InBrief + Chars.LF + CreateDataProcessor.More));
			ReportsAndDataProcessors.Delete(ReverseIndex);
			Continue;
		EndIf;
		TableRow.BinaryData = New BinaryData(FullFileName);
	EndDo;
	
	If Parameters.FirstCDCopyDirectory <> Undefined Then
		Common.DeleteTemporaryDirectory(Parameters.FirstCDCopyDirectory);
	EndIf;
	Common.DeleteTemporaryDirectory(Parameters.WorkingDirectory);
	
EndProcedure

Function DesignerBatchMode(Parameters, PassedLaunchCommands)
	Result = New Structure("Success, InBrief, More", False, "", "");
	ParametersSample = New Structure("WorkingDirectory, User, Password, BINDirectory, PathToConfiguration, FirstCDCopyDirectory");
	CommonClientServer.SupplementStructure(Parameters, ParametersSample, False);
	If Not ValueIsFilled(Parameters.User) Then
		Parameters.User = UserName();
	EndIf;
	If Not FileExists(Parameters.WorkingDirectory) Then
		CreateDirectory(Parameters.WorkingDirectory);
	EndIf;
	If Not ValueIsFilled(Parameters.BINDirectory) Then
		Parameters.BINDirectory = BinDir();
	EndIf;
	If Not ValueIsFilled(Parameters.PathToConfiguration) Then
		Parameters.PathToConfiguration = InfoBaseConnectionString();
		If DesignerIsOpen() Then
			If Common.FileInfobase() Then
				InfobaseDirectory = StringFunctionsClientServer.ParametersFromString(Parameters.PathToConfiguration).file;
				Parameters.FirstCDCopyDirectory = Parameters.WorkingDirectory + "BaseCopy" + GetPathSeparator();
				CreateDirectory(Parameters.FirstCDCopyDirectory);
				FileCopy(InfobaseDirectory + "\1Cv8.1CD", Parameters.FirstCDCopyDirectory + "1Cv8.1CD");
				Parameters.PathToConfiguration = StringFunctionsClientServer.SubstituteParametersToString(
					"File=""%1"";", Parameters.FirstCDCopyDirectory);
			Else
				Result.InBrief = NStr("ru = 'Для выгрузки модулей необходимо закрыть конфигуратор.'; en = 'To export modules, close the designer.'; pl = 'W celu przesłania modułów należy zamknąć konfigurator.';es_ES = 'Para subir los módulos es necesario cerrar el configurador.';es_CO = 'Para subir los módulos es necesario cerrar el configurador.';tr = 'Modülleri dışa aktarmak için yapılandırıcıyı kapatmanız gerekir.';it = 'Per importare i moduli è necessario chiudere il configuratore.';de = 'Um die Module hochzuladen, muss der Konfigurator geschlossen werden.'");
				Return Result;
			EndIf;
		EndIf;
	EndIf;
	
	MessagesFileName = Parameters.WorkingDirectory + "DataExported.log";
	
	StartupCommand = New Array;
	StartupCommand.Add(Parameters.BINDirectory + "1cv8.exe");
	StartupCommand.Add("DESIGNER");
	StartupCommand.Add("/IBConnectionString");
	StartupCommand.Add(Parameters.PathToConfiguration);
	StartupCommand.Add("/N");
	StartupCommand.Add(Parameters.User);
	StartupCommand.Add("/P");
	StartupCommand.Add(Parameters.Password);
	CommonClientServer.SupplementArray(StartupCommand, PassedLaunchCommands);
	StartupCommand.Add("/Out");
	StartupCommand.Add(MessagesFileName);
	StartupCommand.Add("/DisableStartupMessages");
	StartupCommand.Add("/DisableStartupDialogs");
	
	CommandRunParameters = CommonClientServer.ApplicationStartupParameters();
	CommandRunParameters.WaitForCompletion = True;
	
	RunResult = CommonClientServer.StartApplication(StartupCommand, CommandRunParameters);
	
	ReturnCode = RunResult.ReturnCode;
	If ReturnCode = 0 Then
		Result.Success = True;
		Return Result;
	EndIf;
	
	Result.InBrief = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось выгрузить конфигурацию в XML (код ошибки ""%1"")'; en = 'Cannot export configuration to XML (error code ""%1"")'; pl = 'Nie udało się przesłać konfigurację do XML (kod błędu ""%1"")';es_ES = 'No se ha podido subir la configuración en XML (código de error ""%1"")';es_CO = 'No se ha podido subir la configuración en XML (código de error ""%1"")';tr = 'Yapılandırma XML''e aktarılamadı (hata kodu ""%1"")';it = 'Impossibile esportare la configurazione in XML (codice errore ""%1"")';de = 'Fehler beim Hochladen der Konfiguration in XML (Fehlercode ""%1"")'"),
		ReturnCode);
	If FileExists(MessagesFileName) Then
		TextReader = New TextReader(MessagesFileName, , , , False);
		Messages = TrimAll(TextReader.Read());
		TextReader.Close();
		If Messages <> "" Then
			Result.More = StrReplace(Chars.LF + Messages, Chars.LF, Chars.LF + Chars.Tab);
		EndIf;
	EndIf;
	Return Result;
	
EndFunction

Function FileExists(FullFileName)
	File = New File(FullFileName);
	Return File.Exist();
EndFunction

Function DesignerIsOpen()
	Sessions = GetInfoBaseSessions();
	For Each Session In Sessions Do
		If Upper(Session.ApplicationName) = "DESIGNER" Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Function ReadTextFile(FullFileName)
	If Not FileExists(FullFileName) Then
		Return Undefined;
	EndIf;
	TextReader = New TextReader(FullFileName);
	Text = TextReader.Read();
	TextReader.Close();
	Return Text;
EndFunction

Procedure WriteTextFile(FullFileName, Text)
	TextWriter = New TextWriter(FullFileName, TextEncoding.UTF8);
	TextWriter.Write(Text);
	TextWriter.Close();
EndProcedure

Function ReadDOMDocument(PathToFile)
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	DOMBuilder = New DOMBuilder;
	DocumentDOM = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Return DocumentDOM;
EndFunction

Function EvaluateXPathExpression(Expression, DocumentDOM, Dereferencer)
	Return DocumentDOM.EvaluateXPathExpression(Expression, DocumentDOM, Dereferencer);
EndFunction

Procedure WriteDOMDocument(DocumentDOM, FileName)
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(FileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(DocumentDOM, XMLWriter);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Performs batch registration of external reports and data processors in the catalog.

Procedure RegisterReportsAndDataProcessors(ReportsAndDataProcessors)
	
	For Each TableRow In ReportsAndDataProcessors Do
		// Updating/adding.
		If TableRow.Ref = Undefined Then
			CatalogObject = Catalogs.AdditionalReportsAndDataProcessors.CreateItem();
			CatalogObject.UseForObjectForm = True;
			CatalogObject.UseForListForm  = True;
			CatalogObject.EmployeeResponsible               = Users.CurrentUser();
		Else
			CatalogObject = TableRow.Ref.GetObject();
		EndIf;
		
		IsReport      = (TableRow.Kind = "REPORT");
		DataAddress   = PutToTempStorage(TableRow.BinaryData);
		Manager      = ?(IsReport, ExternalReports, ExternalDataProcessors);
		If Common.HasUnsafeActionProtection() Then
			ObjectName = Manager.Connect(DataAddress, , True,
				Common.ProtectionWithoutWarningsDetails());
		Else
			ObjectName = Manager.Connect(DataAddress, , True);
		EndIf;
		ExternalObject = Manager.Create(ObjectName);
		
		ExternalObjectMetadata = ExternalObject.Metadata();
		DataProcessorInfo = TableRow.Information;
		If DataProcessorInfo.Description = Undefined OR DataProcessorInfo.Information = Undefined Then
			If DataProcessorInfo.Description = Undefined Then
				DataProcessorInfo.Description = ExternalObjectMetadata.Presentation();
			EndIf;
			If DataProcessorInfo.Information = Undefined Then
				DataProcessorInfo.Information = ExternalObjectMetadata.Comment;
			EndIf;
		EndIf;
		
		FillPropertyValues(CatalogObject, DataProcessorInfo, "Description, SafeMode, Version, Information");
		
		// Exporting commands settings that can be changed by administrator.
		JobsSearch = New Map;
		For Each ObsoleteCommand In CatalogObject.Commands Do
			If ValueIsFilled(ObsoleteCommand.GUIDScheduledJob) Then
				JobsSearch.Insert(Upper(ObsoleteCommand.ID), ObsoleteCommand.GUIDScheduledJob);
			EndIf;
		EndDo;
		
		RegistrationParameters = New Structure;
		RegistrationParameters.Insert("DataProcessorDataAddress", DataAddress);
		RegistrationParameters.Insert("IsReport", IsReport);
		RegistrationParameters.Insert("DisableConflicts", False);
		RegistrationParameters.Insert("FileName", TableRow.FileName);
		RegistrationParameters.Insert("DisablePublication", False);
		
		CatalogObject.ObjectName = Undefined;
		CatalogObject.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
		CatalogObject.Kind        = GetDataProcessorKindByKindStringPresentation(
			DataProcessorInfo.Kind);
		
		Result = RegisterDataProcessor(CatalogObject, RegistrationParameters);
		If Not Result.Success AND Result.ObjectNameUsed Then
			RegistrationParameters.Insert("DisableConflicts", True);
			RegistrationParameters.Insert("Conflicting", Result.Conflicting);
			Result = RegisterDataProcessor(CatalogObject, RegistrationParameters);
		EndIf;
		If Not Result.Success Then
			If Result.ObjectNameUsed Then
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Имя ""%1"" занято объектами ""%2""'; en = 'The ""%1"" name is used by ""%2"" objects'; pl = 'Nazwa ""%1"" jest zajęta przez obiekty ""%2""';es_ES = 'El nombre ""%1"" está ocupado por objetos ""%2""';es_CO = 'El nombre ""%1"" está ocupado por objetos ""%2""';tr = '""%1"" adı ""%2"" nesne tarafından kullanılıyor';it = 'Il nome ""%1"" è utilizzato dagli oggetti ""%2""';de = 'Der Name ""%1"" wird von den Objekten ""%2"" besetzt'"),
					ObjectName,
					String(Result.Conflicting));
			EndIf;
			WriteLogEvent(
				AdditionalReportsAndDataProcessorsClientServer.SubsystemDescription(False),
				EventLogLevel.Error,
				Metadata.CommonTemplates.Find(TableRow.TemplateName),
				,
				Result.ErrorText);
			Continue;
		EndIf;
		
		CatalogObject.DataProcessorStorage = New ValueStorage(TableRow.BinaryData);
		CatalogObject.ObjectName         = ExternalObjectMetadata.Name;
		CatalogObject.FileName           = TableRow.FileName;
		
		// Clearing and importing new commands.
		For Each Command In CatalogObject.Commands Do
			GUIDScheduledJob = JobsSearch.Get(Upper(Command.ID));
			If GUIDScheduledJob <> Undefined Then
				Command.GUIDScheduledJob = GUIDScheduledJob;
				JobsSearch.Delete(Upper(Command.ID));
			EndIf;
		EndDo;
		
		// Deleting outdated jobs.
		For Each KeyAndValue In JobsSearch Do
			Try
				Job = ScheduledJobsServer.Job(KeyAndValue.Value);
				Job.Delete();
			Except
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.Catalogs.AdditionalReportsAndDataProcessors,
					CatalogObject.Ref,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка при удалении задания ""%1"":%2'; en = 'An error occurred while deleting the ""%1"" job:%2'; pl = 'Błąd podczas usuwania zadania ""%1"":%2';es_ES = 'Error al eliminar la tarea ""%1"":%2';es_CO = 'Error al eliminar la tarea ""%1"":%2';tr = '""%2"" görevi kaldırırken bir hata oluştu: %1';it = 'Si è verificato un errore durante l''eliminazione del compito ""%1"":%2';de = 'Fehler beim Löschen der Aufgabe ""%1"": %2'"),
						KeyAndValue.Value,
						Chars.LF + DetailErrorDescription(ErrorInfo())));
			EndTry;
		EndDo;
		
		If CheckGlobalDataProcessor(CatalogObject.Kind) Then
			MetadataObjectsTable = AttachedMetadataObjects(CatalogObject.Kind);
			For Each TableRow In MetadataObjectsTable Do
				SectionRef = TableRow.Ref;
				SectionRow = CatalogObject.Sections.Find(SectionRef, "Section");
				If SectionRow = Undefined Then
					SectionRow = CatalogObject.Sections.Add();
					SectionRow.Section = SectionRef;
				EndIf;
			EndDo;
		Else
			For Each AssignmentDetails In DataProcessorInfo.Purpose Do
				MetadataObject = Metadata.FindByFullName(AssignmentDetails);
				If MetadataObject = Undefined Then
					Continue;
				EndIf;
				AssignmentObjectReference = Common.MetadataObjectID(MetadataObject);
				AssignmentRow = CatalogObject.Purpose.Find(AssignmentObjectReference, "RelatedObject");
				If AssignmentRow = Undefined Then
					AssignmentRow = CatalogObject.Purpose.Add();
					AssignmentRow.RelatedObject = AssignmentObjectReference;
				EndIf;
			EndDo;
		EndIf;
		
		InfobaseUpdate.WriteObject(CatalogObject, , True);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other

// Sets the data processor publication kind used for conflicting additional reports and data processors.
Procedure DisableConflicting(DataProcessorObject)
	KindDebugMode = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	AvaliableKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	If AvaliableKinds.Find(KindDebugMode) Then
		DataProcessorObject.Publication = KindDebugMode;
	Else
		DataProcessorObject.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	EndIf;
EndProcedure

// For internal use.
Function RegisterDataProcessor(Val Object, Val RegistrationParameters) Export
	
	KindAdditionalDataProcessor = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	KindAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	ReportKind                   = Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	
	// Gets a data processor file from temporary storage, attempts to create an external data processor 
	// (report) object, gets information from the external data processor (report) object.
	
	If RegistrationParameters.DisableConflicts Then
		For Each ListItem In RegistrationParameters.Conflicting Do
			ConflictingObject = ListItem.Value.GetObject();
			DisableConflicting(ConflictingObject);
			ConflictingObject.Write();
		EndDo;
	ElsIf RegistrationParameters.DisablePublication Then
		DisableConflicting(Object);
	EndIf;
	
	Result = New Structure("ObjectName, OldObjectName, Success, ObjectNameUsed, Conflicting, ErrorText, BriefErrorPresentation");
	Result.ObjectNameUsed = False;
	Result.Success = False;
	If Object.IsNew() Then
		Result.OldObjectName = Object.ObjectName;
	Else
		Result.OldObjectName = Common.ObjectAttributeValue(Object.Ref, "ObjectName");
	EndIf;
	
	RegistrationData = GetRegistrationData(Object, RegistrationParameters, Result);
	If RegistrationData = Undefined
		Or RegistrationData.Count() = 0
		Or ValueIsFilled(Result.ErrorText)
		Or ValueIsFilled(Result.BriefErrorPresentation) Then
		Return Result;
	EndIf;
	
	If RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		AND Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Result.ErrorText = NStr("ru = 'Работа с печатными формами не поддерживается.'; en = 'Print forms are not supported.'; pl = 'Praca z formularzami wydruku nie jest obsługiwana.';es_ES = 'No se admite el uso de los formularios de impresión.';es_CO = 'No se admite el uso de los formularios de impresión.';tr = 'Yazdırma formları desteklenmiyor.';it = 'I moduli di stampa non sono supportati';de = 'Die Arbeit mit Druckformularen wird nicht unterstützt.'");
		Return Result;
	EndIf;
	
	// If the report is published, a check for uniqueness of the object name used to register the 
	//     additional report in the application is performed.
	If Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used Then
		// Checking the name
		QueryText =
		"SELECT
		|	CatalogTable.Ref,
		|	CatalogTable.Presentation
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS CatalogTable
		|WHERE
		|	CatalogTable.ObjectName = &ObjectName
		|	AND &AdditReportCondition
		|	AND CatalogTable.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
		|	AND CatalogTable.DeletionMark = FALSE
		|	AND CatalogTable.Ref <> &Ref";
		
		AddlReportsKinds = New Array;
		AddlReportsKinds.Add(KindAdditionalReport);
		AddlReportsKinds.Add(ReportKind);
		
		Query = New Query;
		Query.SetParameter("ObjectName",     Result.ObjectName);
		Query.SetParameter("AddlReportsKinds", AddlReportsKinds);
		Query.SetParameter("Ref", Object.Ref);
		
		If RegistrationParameters.IsReport Then
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "CatalogTable.Kind IN (&AddlReportsKinds)");
		Else
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "NOT CatalogTable.Kind IN (&AddlReportsKinds)");
		EndIf;
		
		Query.Text = QueryText;
		
		SetPrivilegedMode(True);
		Conflicting = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		If Conflicting.Count() > 0 Then
			Result.ObjectNameUsed = True;
			Result.Conflicting = New ValueList;
			For Each TableRow In Conflicting Do
				Result.Conflicting.Add(TableRow.Ref, TableRow.Presentation);
			EndDo;
			Return Result;
		EndIf;
	EndIf;
	
	If RegistrationData.SafeMode
		OR Users.IsFullUser(, True) Then
		// doing nothing
	Else
		Result.ErrorText = NStr("ru = 'Для подключения обработки, запускаемой в небезопасном режиме, требуются административные права.'; en = 'Administrative rights are required to attach a data processor that runs in unsafe mode.'; pl = 'Aby podłączyć przetwarzanie danych uruchamiane w trybie niebezpiecznym, wymagane są uprawnienia administracyjne.';es_ES = 'Para conectar el procesador de datos, lanzar en el modo inseguro, se requieren los derechos administrativos.';es_CO = 'Para conectar el procesador de datos, lanzar en el modo inseguro, se requieren los derechos administrativos.';tr = 'Güvenli olmayan modda çalışan veri işlemcisini bağlamak için yönetimsel haklar gereklidir.';it = 'Sono richiesti diritti amministrativi per allegare un elaboratore dati che operi in modalità non sicura.';de = 'Um den Datenprozessor im unsicheren Modus auszuführen, sind Administratorrechte erforderlich.'");
		Return Result;
	EndIf;
	
	If NOT Object.IsNew() AND RegistrationData.Kind <> Object.Kind Then
		Result.ErrorText = 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Вид загружаемого объекта (%1) не соответствует текущему (%2).
					|Для загрузки нового объекта нажмите ""Создать"".'; 
					|en = 'Kind of imported object (%1) does not correspond to the current one (%2).
					|Click ""Create"" to import a new object.'; 
					|pl = 'Zaimportowany typ obiektu (%1) nie odpowiada bieżącemu (%2).
					|Aby zaimportować nowy obiekt, kliknij Utwórz.';
					|es_ES = 'Tipo del objeto importado (%1) no corresponde al actual (%2).
					|Para importar un nuevo objeto, hacer clic en Crear.';
					|es_CO = 'Tipo del objeto importado (%1) no corresponde al actual (%2).
					|Para importar un nuevo objeto, hacer clic en Crear.';
					|tr = 'İçe aktarılan nesne türü (%1) mevcut olanla (%2) uyuşmuyor. 
					|Yeni bir nesneyi içe aktarmak için Oluştur''u tıklayın.';
					|it = 'Il tipo di oggetto importato (%1) non corrisponde a quello corrente (%2).
					|Cliccare su ""Creare"" per importare un nuovo oggetto.';
					|de = 'Importierte Objektart (%1) entspricht nicht der aktuellen (%2).
					|Um ein neues Objekt zu importieren, klicken Sie auf Erstellen.'"),
				String(RegistrationData.Kind),
				String(Object.Kind));
		Return Result;
	ElsIf RegistrationParameters.IsReport <> (RegistrationData.Kind = KindAdditionalReport OR RegistrationData.Kind = ReportKind) Then
		Result.ErrorText = NStr("ru = 'Вид обработки, указанный в сведениях о внешней обработке, не соответствует ее расширению.'; en = 'Data processor kind specified in the external data processor information does not match the extension.'; pl = 'Typ opracowania z zewnętrznego przetwarzania danych nie odpowiada jego rozszerzeniu.';es_ES = 'Tipo del procesador de datos de los datos del procesador de datos externo no corresponde a su extensión.';es_CO = 'Tipo del procesador de datos de los datos del procesador de datos externo no corresponde a su extensión.';tr = 'Harici veri işlemcisi bilgilerinde belirtilen veri işlemcisi türü, uzantısına uymuyor.';it = 'Tipo di elaboratore dati indicato nelle informazioni dell''elaboratore dati esterno non corrisponde all''estensione.';de = 'Datenverarbeitertyp aus externen Datenprozessordaten entspricht nicht seiner Erweiterung.'");
		Return Result;
	EndIf;
	
	Object.Description    = RegistrationData.Description;
	Object.Version          = RegistrationData.Version;
	
	If RegistrationData.Property("SSLVersion") Then
		If CommonClientServer.CompareVersions(RegistrationData.SSLVersion, "2.2.2.0") > 0 Then
			Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2;
		Else
			Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
		EndIf;
	Else
		Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3;
	EndIf;
	
	If RegistrationData.Property("SafeMode") Then
		Object.SafeMode = RegistrationData.SafeMode;
	EndIf;
	
	Object.Information      = RegistrationData.Information;
	Object.FileName        = RegistrationParameters.FileName;
	Object.ObjectName      = Result.ObjectName;
	
	Object.UseOptionStorage = False;
	If (RegistrationData.Kind = KindAdditionalReport) OR (RegistrationData.Kind = ReportKind) Then
		If RegistrationData.VariantsStorage = "ReportsVariantsStorage"
			OR (Metadata.ReportsVariantsStorage <> Undefined
				AND Metadata.ReportsVariantsStorage.Name = "ReportsVariantsStorage") Then
			Object.UseOptionStorage = True;
		EndIf;
		RegistrationData.Property("DefineFormSettings", Object.DeepIntegrationWithReportForm);
	EndIf;
	
	// A different data processor is imported (object name or data processor kind was changed.
	If Object.IsNew() OR Object.ObjectName <> Result.ObjectName OR Object.Kind <> RegistrationData.Kind Then
		Object.Purpose.Clear();
		Object.Sections.Clear();
		Object.Kind = RegistrationData.Kind;
	EndIf;
	
	// If the purpose is not specified, setting the value from the data processor.
	If Object.Purpose.Count() = 0
		AND Object.Kind <> KindAdditionalReport
		AND Object.Kind <> KindAdditionalDataProcessor Then
		
		If RegistrationData.Property("Purpose") Then
			MetadataObjectsTable = AttachedMetadataObjects(Object.Kind);
			
			For Each FullMetadataObjectName In RegistrationData.Purpose Do
				PointPosition = StrFind(FullMetadataObjectName, ".");
				If Mid(FullMetadataObjectName, PointPosition + 1) = "*" Then // For example, [Catalog.*].
					Search = New Structure("Kind", Left(FullMetadataObjectName, PointPosition - 1));
				Else
					Search = New Structure("FullName", FullMetadataObjectName);
				EndIf;
				
				FoundItems = MetadataObjectsTable.FindRows(Search);
				For Each TableRow In FoundItems Do
					AssignmentRow = Object.Purpose.Add();
					AssignmentRow.RelatedObject = TableRow.Ref;
				EndDo;
			EndDo;
		EndIf;
		
		Object.Purpose.GroupBy("RelatedObject", "");
		
	EndIf;
	
	Object.Commands.Clear();
	
	// Initializing commands
	
	For Each DetailsForCommand In RegistrationData.Commands Do
		
		If NOT ValueIsFilled(DetailsForCommand.StartupOption) Then
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Для команды ""%1"" не определен способ запуска.'; en = 'Start method is not specified for command %1.'; pl = 'Metoda uruchamiania nie jest zdefiniowana dla polecenia ""%1"".';es_ES = 'El método de lanzamiento no está definido para el comando ""%1"".';es_CO = 'El método de lanzamiento no está definido para el comando ""%1"".';tr = '""%1"" komutu için başlatma yöntemi tanımlanmadı.';it = 'Il metodo di avvio non è specificato per il comando %1.';de = 'Die Startmethode ist nicht für den Befehl ""%1"" definiert.'"), DetailsForCommand.Presentation));
		EndIf;
		
		Command = Object.Commands.Add();
		FillPropertyValues(Command, DetailsForCommand);
		
	EndDo;
	
	// Reading permissions requierd by the additional data processor.
	Object.Permissions.Clear();
	Permissions = Undefined;
	If RegistrationData.Property("Permissions", Permissions) Then
		
		For Each Permission In Permissions Do
			
			XDTOType = Permission.Type();
			
			TSRow = Object.Permissions.Add();
			TSRow.PermissionKind = XDTOType.Name;
			
			Parameters = New Structure();
			
			For Each XDTOProperty In XDTOType.Properties Do
				
				Container = Permission.GetXDTO(XDTOProperty.Name);
				
				If Container <> Undefined Then
					Parameters.Insert(XDTOProperty.Name, Container.Value);
				Else
					Parameters.Insert(XDTOProperty.Name);
				EndIf;
				
			EndDo;
			
			TSRow.Parameters = New ValueStorage(Parameters);
			
		EndDo;
		
	EndIf;
	
	Object.EmployeeResponsible = Users.CurrentUser();
	
	Result.Success = True;
	
	Return Result;
	
EndFunction

// For internal use.
Function GetRegistrationData(Val Object, Val RegistrationParameters, Val RegistrationResult)

	RegistrationData = New Structure;
	StandardProcessing = True;
	
	SaaSIntegration.OnGetRegistrationData(Object, RegistrationData, StandardProcessing);
	If StandardProcessing Then
		OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult);
	EndIf;
	
	Return RegistrationData;
EndFunction

// For internal use.
Procedure OnGetRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult)
	
	// Attaching and getting the name to be used when attaching the object.
	Manager = ?(RegistrationParameters.IsReport, ExternalReports, ExternalDataProcessors);
	
	ErrorInformation = Undefined;
	Try
		#If ThickClientOrdinaryApplication Then
			RegistrationResult.ObjectName = GetTempFileName();
			BinaryData = GetFromTempStorage(RegistrationParameters.DataProcessorDataAddress);
			BinaryData.Write(RegistrationResult.ObjectName);
		#Else
			If Common.HasUnsafeActionProtection() Then
				RegistrationResult.ObjectName =
					TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True,
						Common.ProtectionWithoutWarningsDetails()));
			Else
				RegistrationResult.ObjectName =
					TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True));
			EndIf;
		#EndIf
		
		// Getting external data processor information.
		ExternalObject = Manager.Create(RegistrationResult.ObjectName);
		ExternalObjectMetadata = ExternalObject.Metadata();
		
		ExternalDataProcessorInfo = ExternalObject.ExternalDataProcessorInfo();
		CommonClientServer.SupplementStructure(RegistrationData, ExternalDataProcessorInfo, True);
	Except
		ErrorInformation = ErrorInfo();
	EndTry;
	#If ThickClientOrdinaryApplication Then
		Try
			DeleteFiles(RegistrationResult.ObjectName);
		Except
			WarningText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при получении регистрационных данных:
				|Ошибка при удалении временного файла ""%1"":
				|%2'; 
				|en = 'An error occurred while receiving registration data:
				|An error occurred while deleting the ""%1"" temporary file:
				|%2'; 
				|pl = 'Błąd podczas pobierania danych rejestracyjnych:
				|Błąd podczas usuwania pliku tymczasowego ""%1"":
				|%2';
				|es_ES = 'Error al recibir los datos de registro:
				|Error al eliminar el archivo temporal ""%1"":
				|%2';
				|es_CO = 'Error al recibir los datos de registro:
				|Error al eliminar el archivo temporal ""%1"":
				|%2';
				|tr = 'Kayıt alma hatası: 
				| ""%1"" geçici dosya silme hatası : 
				|%2';
				|it = 'Si è verificato un errore durante la ricezione dei dati di registrazione:
				|Si è verificato un errore durante l''eliminazione del file temporaneo ""%1"":
				|%2';
				|de = 'Fehler beim Empfangen von Registrierungsdaten:
				|Fehler beim Löschen einer temporären Datei ""%1"":
				|%2'"),
				RegistrationResult.ObjectName,
				DetailErrorDescription(ErrorInfo()));
			WriteWarning(Object.Ref, WarningText);
		EndTry;
	#EndIf
	If ErrorInformation <> Undefined Then
		If RegistrationParameters.IsReport Then
			ErrorText = NStr("ru='Невозможно подключить дополнительный отчет из файла.
			|Возможно, он не подходит для этой версии программы.'; 
			|en = 'Cannot attach an additional report from a file.
			|It might not be compatible with this application version.'; 
			|pl = 'Nie można włączyć dodatkowego sprawozdania z pliku.
			|Może on być niezgodny z wersją aplikacji.';
			|es_ES = 'No se puede activar el informe adicional desde el archivo.
			|Puede ser no compatible con la versión de la aplicación.';
			|es_CO = 'No se puede activar el informe adicional desde el archivo.
			|Puede ser no compatible con la versión de la aplicación.';
			|tr = 'Dosyadan ek rapor etkinleştirilemiyor. 
			|Uygulama sürümü ile uyumlu olmayabilir.';
			|it = 'Impossibile connettere il rreport aggiuntivo dal file.
			|Probabilmente non è adatto a questa versione del programma.';
			|de = 'Der zusätzliche Bericht aus der Datei kann nicht aktiviert werden.
			|Es ist möglicherweise nicht mit der Anwendungsversion kompatibel.'");
		Else
			ErrorText = NStr("ru='Невозможно подключить дополнительную обработку из файла.
			|Возможно, она не подходит для этой версии программы.'; 
			|en = 'Cannot attach an additional data processor from a file.
			|It might not be compatible with this application version.'; 
			|pl = 'Nie można włączyć dodatkowego przetwarzania danych z pliku.
			|Może ono nie odpowiadać tej wersji aplikacji.';
			|es_ES = 'No se puede activar el procesador adicional desde el archivo.
			|Puede ser no apto para esta versión de la aplicación.';
			|es_CO = 'No se puede activar el procesador adicional desde el archivo.
			|Puede ser no apto para esta versión de la aplicación.';
			|tr = 'Dosyadan ek işlemci etkinleştirilemiyor. 
			|Uygulama sürümü ile uyumlu olmayabilir.';
			|it = 'Impossibile allegare un elaboratore dati aggiuntivo da file. 
			|Potrebbe non essere compatibile con questa versione dell''applicazione.';
			|de = 'Der zusätzliche Prozessor kann nicht aus der Datei aktiviert werden.
			|Möglicherweise ist er für diese Version der Anwendung nicht geeignet.'");
		EndIf;
		ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("ru = 'Техническая информация:'; en = 'Technical information:'; pl = 'Informacja techniczna:';es_ES = 'Información técnica:';es_CO = 'Información técnica:';tr = 'Teknik bilgi:';it = 'Informazione tecnica:';de = 'Technische Information:'") + Chars.LF;
		RegistrationResult.BriefErrorPresentation = BriefErrorDescription(ErrorInformation);
		RegistrationResult.ErrorText = ErrorText + RegistrationResult.BriefErrorPresentation;
		WriteError(Object.Ref, ErrorText + DetailErrorDescription(ErrorInformation));
		Return;
	EndIf;
	
	If RegistrationData.Description = Undefined OR RegistrationData.Information = Undefined Then
		If RegistrationData.Description = Undefined Then
			RegistrationData.Description = ExternalObjectMetadata.Presentation();
		EndIf;
		If RegistrationData.Information = Undefined Then
			RegistrationData.Information = ExternalObjectMetadata.Comment;
		EndIf;
	EndIf;
	
	If TypeOf(RegistrationData.Kind) <> Type("EnumRef.AdditionalReportsAndDataProcessorsKinds") Then
		RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds[RegistrationData.Kind];
	EndIf;
	
	RegistrationData.Insert("VariantsStorage");
	If RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport
		Or RegistrationData.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		If ExternalObjectMetadata.VariantsStorage <> Undefined Then
			RegistrationData.VariantsStorage = ExternalObjectMetadata.VariantsStorage.Name;
		EndIf;
	EndIf;
	
	RegistrationData.Commands.Columns.Add("StartupOption");
	
	For Each DetailsForCommand In RegistrationData.Commands Do
		DetailsForCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods[DetailsForCommand.Use];
	EndDo;
	
	#If ThickClientOrdinaryApplication Then
		RegistrationResult.ObjectName = ExternalObjectMetadata.Name;
	#EndIf
EndProcedure

// Displays the filling commands in object forms.
Procedure OnDetermineFillingCommandsAttachedToObject(Commands, MOIDs, QuickSearchByMOIDs)
	Query = New Query;
	Query.Text =
	"SELECT
	|	Table.Ref,
	|	Table.Commands.(
	|		ID,
	|		StartupOption,
	|		Presentation,
	|		ShowNotification,
	|		Hide
	|	),
	|	Table.Purpose.(
	|		RelatedObject
	|	)
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS Table
	|WHERE
	|	Table.Purpose.RelatedObject IN(&MOIDs)
	|	AND Table.Kind = &Kind
	|	AND Table.UseForObjectForm = TRUE
	|	AND Table.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
	|	AND Table.Publication <> VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled)
	|	AND Table.DeletionMark = FALSE";
	Query.SetParameter("MOIDs", MOIDs);
	Query.SetParameter("Kind", Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling);
	If AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Query.Text = StrReplace(Query.Text, "AND Table.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)", "");
	Else
		Query.Text = StrReplace(Query.Text, "AND Table.Publication <> VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled)", "");
	EndIf;
	
	HandlerParametersKeys = "Ref, ID, StartupOption, Presentation, ShowNotification, IsReport";
	FillingForm = Enums.AdditionalDataProcessorsCallMethods.FillingForm;
	
	DeepIntegrationWithSubsystemInSaaSIsUsed = DeepIntegrationWithSubsystemInSaaSIsUsed();
	If DeepIntegrationWithSubsystemInSaaSIsUsed Then
		ModuleAdditionalReportsAndDataProcessorsSaaS = Common.CommonModule("AdditionalReportsAndDataProcessorsSaaS");
	EndIf;
	
	Table = Query.Execute().Unload();
	For Each ReportOrDataProcessor In Table Do
		If DeepIntegrationWithSubsystemInSaaSIsUsed
			AND Not ModuleAdditionalReportsAndDataProcessorsSaaS.ThisIsSuppliedProcessing(ReportOrDataProcessor.Ref) Then
			Continue;
		EndIf;
		
		ObjectFillingTypes = New Array;
		For Each PurposeTableRow In ReportOrDataProcessor.Purpose Do
			Source = QuickSearchByMOIDs[PurposeTableRow.RelatedObject];
			If Source = Undefined Then
				Continue;
			EndIf;
			AttachableCommands.SupplyTypesArray(ObjectFillingTypes, Source.DataRefType);
		EndDo;
		
		For Each TableRow In ReportOrDataProcessor.Commands Do
			If TableRow.Hide Then
				Continue;
			EndIf;
			Command = Commands.Add();
			Command.Kind            = "ObjectsFilling";
			Command.Presentation  = TableRow.Presentation;
			Command.Importance       = "SeeAlso";
			Command.Order        = 50;
			Command.ChangesSelectedObjects = True;
			If TableRow.StartupOption = FillingForm Then
				Command.Handler  = "AdditionalReportsAndDataProcessors.PopulateCommandHandler";
				Command.WriteMode = "DoNotWrite";
			Else
				Command.Handler  = "AdditionalReportsAndDataProcessorsClient.PopulateCommandHandler";
				Command.WriteMode = "Write";
			EndIf;
			Command.ParameterType = New TypeDescription(ObjectFillingTypes);
			Command.AdditionalParameters = New Structure(HandlerParametersKeys);
			FillPropertyValues(Command.AdditionalParameters, TableRow);
			Command.AdditionalParameters.Ref = ReportOrDataProcessor.Ref;
			Command.AdditionalParameters.IsReport = False;
		EndDo;
	EndDo;
EndProcedure

// Converts a string representation of the version to a number.
//
Function VersionAsNumber(VersionAsString)
	If IsBlankString(VersionAsString) Or VersionAsString = "0.0.0.0" Then
		Return 0;
	EndIf;
	
	Digit = 0;
	
	Result = 0;
	
	TypeDescriptionNumber = New TypeDescription("Number");
	Balance = VersionAsString;
	PointPosition = StrFind(Balance, ".");
	While PointPosition > 0 Do
		NumberAsString = Left(Balance, PointPosition - 1);
		Number = TypeDescriptionNumber.AdjustValue(NumberAsString);
		Result = Result * 1000 + Number;
		Balance = Mid(Balance, PointPosition + 1);
		PointPosition = StrFind(Balance, ".");
		Digit = Digit + 1;
	EndDo;
	
	Number = TypeDescriptionNumber.AdjustValue(Balance);
	Result = Result * 1000 + Number;
	Digit = Digit + 1;
	
	// The version numbers after the fourth dot are returned after comma.
	// For example, for version "1.2.3.4.5.6.7" returns 1002003004,005006007.
	If Digit > 4 Then
		Result = Result / Pow(1000, Digit - 4);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
