#Region Public

// Shows attached commands in the form.
//
// Parameters:
//   Form - ClientApplicationForm - a form, where the commands are to be placed.
//   PlacingParameters - Undefined, Structure - placing command parameters.
//       It is used when a form has several lists (in this case, several calls of this procedure are 
//       placed, specifying the second parameter), or when source types epend on the form opening 
//       parameters.
//       See key components in the PlacementParameters().
//
Procedure OnCreateAtServer(Form, PlacementParameters = Undefined) Export
	FormName = Form.FormName;
	
	SourcesCommaSeparated = "";
	If PlacementParameters = Undefined Then
		PlacementParameters = PlacementParameters();
	Else
		If TypeOf(PlacementParameters.Sources) = Type("TypeDescription") Then
			Types = PlacementParameters.Sources.Types();
			For Each Type In Types Do
				MetadataObject = Metadata.FindByType(Type);
				If MetadataObject <> Undefined Then
					SourcesCommaSeparated = SourcesCommaSeparated + ?(SourcesCommaSeparated = "", "", ",") + MetadataObject.FullName();
				EndIf;
			EndDo;
		ElsIf TypeOf(PlacementParameters.Sources) = Type("Array") Then
			For Each MetadataObject In PlacementParameters.Sources Do
				If TypeOf(MetadataObject) = Type("MetadataObject") Then
					SourcesCommaSeparated = SourcesCommaSeparated + ?(SourcesCommaSeparated = "", "", ",") + MetadataObject.FullName();
				ElsIf MetadataObject <> Undefined Then
					CommonClientServer.CheckParameter(
						"AttachableCommands.OnCreateAtServer",
						"PlacementParameters.Sources[...]",
						MetadataObject,
						New TypeDescription("MetadataObject"));
				EndIf;
			EndDo;
		ElsIf PlacementParameters.Sources <> Undefined Then
			CommonClientServer.CheckParameter(
				"AttachableCommands.OnCreateAtServer",
				"PlacementParameters.Sources",
				PlacementParameters.Sources,
				New TypeDescription("TypeDescription, Array"));
		EndIf;
	EndIf;
	
	IsObjectForm = Undefined;
	Parameters = Form.Parameters;
	HasListParameters  = Parameters.Property("Filter") AND Parameters.Property("CurrentRow");
	HasObjectParameters = Parameters.Property("Key")  AND Parameters.Property("Base");
	If HasListParameters <> HasObjectParameters Then
		IsObjectForm = HasObjectParameters;
	EndIf;
	// You cannot get metadata of external report and data processor forms having only the form name, 
	// that is why the definition of command sources is performed before calling Cached.
	If SourcesCommaSeparated = "" AND SpecifyCommandsSources(FormName) Then
		If HasObjectParameters Then
			MetadataObject = Metadata.FindByType(TypeOf(Parameters.Key));
			If MetadataObject <> Undefined Then
				SourcesCommaSeparated = MetadataObject.FullName();
			EndIf;
		EndIf;
		If SourcesCommaSeparated = "" Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В формах отчетов, обработок и в общих формах
					|при вызове процедуры ""%1""
					|требуется явно указывать параметр ""%2""'; 
					|en = 'Explicitly specify the ""%2"" parameter
					|in forms of reports, data processors, and in common forms
					|while calling the ""%1"" procedure'; 
					|pl = 'W formularzach sprawozdań, przetwarzań i w ogólnych formularzach
					|podczas wezwania procedury ""%1""
					|należy wyraźnie wskazywać parametr ""%2""';
					|es_ES = 'En los formularios de informes, procesamientos y en formularios comunes
					|al llamar el procedimiento ""%1""
					|se requiere indicar el parámetro ""%2""';
					|es_CO = 'En los formularios de informes, procesamientos y en formularios comunes
					|al llamar el procedimiento ""%1""
					|se requiere indicar el parámetro ""%2""';
					|tr = 'Rapor, işlem formlarında ve genel formlarda 
					| ""%1""
					| prosedürü çağırdığınızda ""%2"" parametresi açık belirtilmelidir';
					|it = 'Indicare esplicitamente il parametro ""%2""
					|nei moduli di report, elaboratori dati e modulo comuni
					|durante la chiamata della procedura ""%1""';
					|de = 'In den Formularen von Berichten, Behandlungen und allgemeinen Formularen ist es
					|beim Aufruf der Prozedur ""%1""
					|erforderlich, den Parameter ""%2"" explizit anzugeben'"),
				"AttachableCommands.OnCreateAtServer",
				"PlacementParameters.Sources");
		EndIf;
	EndIf;
	
	FormCache = AttachableCommandsCached.FormCache(FormName, SourcesCommaSeparated, IsObjectForm);
	PlacementParameters.Insert("HasVisibilityConditions", FormCache.HasVisibilityConditions);
	PlacementParameters.Insert("IsObjectForm", FormCache.IsObjectForm);
	
	If FormCache.FunctionalOptions.Count() > 0 Then
		Form.SetFormFunctionalOptionParameters(FormCache.FunctionalOptions);
	EndIf;
	
	Commands = FormCache.Commands.Copy();
	OutputCommand(Form, Commands, PlacementParameters);
	
EndProcedure

// Constructor of the similarly named OnCreateAtServer procedure parameter.
//
// Returns:
//   Structure - placement parameters of attachable commands.
//       * Sources - TypesDetaild, Array - command sources.
//           Used for secondary lists, as well as in object forms that are not command providers 
//           (data processors, common forms). The array waits for items of the MetadataObject type.
//       * CommandBar - FormGroup - a command bar or a group of commands that displays submenu.
//           It is used as a parent to create submenu if it is missing.
//           If it is not specified, the AttachableCommands group is searched first.
//       * GroupsPrefix - String - an addition to submenu and command bar name.
//           It is used if you need to add prefixes to groups with commands (in particular, when the form has several tables).
//           For the prefix use the form table name, for which commands are output.
//           For example, if GroupsPrefix = WarehouseDocuments (secondary form table name), submenus 
//           named WarehouseDocumentsSubmenuPrint, WarehouseDocuments SubmenuReports, and so on are used.
//
Function PlacementParameters() Export
	Result = New Structure("Sources, CommandBar, GroupsPrefix");
	Result.GroupsPrefix = "";
	Return Result;
EndFunction

// A handler of the form command that requires a context server call.
//
// Parameters:
//   Form - ClientApplicationForm - a form, from which the command isexecuted.
//   CallParameters - Structure - call parameters.
//   Source - FormTable, FormDataStructure - an object or a form list with the Reference field.
//   Result - Structure - the result of command execution.
//
Procedure ExecuteCommand(Val Form, Val CallParameters, Val Source, Result) Export
	Result = New Structure;
	Result.Insert("Text",    Undefined);
	Result.Insert("More", Undefined);
	
	If TypeOf(CallParameters) <> Type("Structure")
		Or CallParameters.Count() <> 2
		Or TypeOf(Form) <> Type("ClientApplicationForm") Then
		Return;
	EndIf;
	
	SettingsAddress = Form.AttachableCommandsParameters.CommandsTableAddress;
	CommandDetails = CommandDetails(CallParameters.CommandNameInForm, SettingsAddress);
	
	Context = AttachableCommandsClientServer.CommandExecutionParametersTemplate();
	Context.CommandDetails = New Structure(CommandDetails);
	Context.Form = Form;
	Context.IsObjectForm = TypeOf(Source) = Type("FormDataStructure");
	Context.Source = Source;
	Context.Insert("Result", Result);
	
	ExportProcedureParameters = New Array;
	ExportProcedureParameters.Add(CallParameters.CommandParameter);
	ExportProcedureParameters.Add(Context);
	
	Handler = CommandDetails.Handler;
	CommonModulePrefix = Lower("CommonModule.");
	If StrStartsWith(Lower(Handler), CommonModulePrefix) Then
		Handler = Mid(Handler, StrLen(CommonModulePrefix) + 1);
	EndIf;
	
	Common.ExecuteConfigurationMethod(Handler, ExportProcedureParameters);
EndProcedure

// Sets the visibility conditions of the command on the form, depending on the context.
//
// Parameters:
//   Command      - ValueTableRow - a command, for which the visibility condition is added.
//   Attribute     - String                - an object attribute name.
//   Value     - Arbitrary          - an object attribute value. The parameter is required for all 
//                                          kinds of comparisons except for Filled and NotFilled.
//   ComparisonType            - DataCompositionComparisonType - a comparison type.
//       You can use the following types of comparison:
//         DataCompositionComparisonType.Equal,
//         DataCompositionComparisonType.NotEqual,
//         DataCompositionComparisonType.Filled,
//         DataCompositionComparisonType.NotFilled,
//         DataCompositionComparisonType.InList,
//         DataCompositionComparisonType.NotInList,
//         DataCompositionComparisonType.Greater,
//         DataCompositionComparisonType.Less,
//         DataCompositionComparisonType.GreaterOrEqual,
//         DataCompositionComparisonType.LessOrEqual,
//       The default value: DataCompositionComparisonType.Equal.
//
Procedure AddCommandVisibilityCondition(Command, Attribute, Value = Undefined, Val ComparisonType = Undefined) Export
	If ComparisonType = Undefined Then
		ComparisonType = DataCompositionComparisonType.Equal;
	EndIf;
	VisibilityCondition = New Structure;
	VisibilityCondition.Insert("Attribute", Attribute);
	VisibilityCondition.Insert("ComparisonType", ComparisonType);
	VisibilityCondition.Insert("Value", Value);
	Command.VisibilityConditions.Add(VisibilityCondition);
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Event handlers:

// Generates a table of common settings for all extensions attached to the metadata object.
Function AttachedObjects(SourceDetails, AttachedObjects = Undefined, InterfaceSettings = Undefined) Export
	Sources = CommandsSourcesTree();
	If TypeOf(SourceDetails) = Type("CatalogRef.MetadataObjectIDs") Then
		Source = Sources.Rows.Add();
		Source.MetadataRef = SourceDetails;
		Source.DataRefType = Common.ObjectAttributeValue(SourceDetails, "EmptyRefValue");
	Else
		Source = SourceDetails;
	EndIf;
	
	If AttachedObjects = Undefined Then
		AttachedObjects = AttachableObjectsTable(InterfaceSettings);
	EndIf;
	If Source.MetadataRef = Undefined Then
		Return AttachedObjects;
	EndIf;
	
	AttachedObjectsFullNames = AttachableCommandsCached.Parameters().AttachedObjects[Source.MetadataRef];
	If AttachedObjectsFullNames = Undefined Then
		Return AttachedObjects;
	EndIf;
	
	For Each FullName In AttachedObjectsFullNames Do
		AttachedObject = AttachedObjects.Find(FullName, "FullName");
		If AttachedObject = Undefined Then
			AttachableObjectSettings = AttachableObjectSettings(FullName, InterfaceSettings);
			If AttachableObjectSettings = Undefined Then
				Continue;
			EndIf;
			AttachedObject = AttachedObjects.Add();
			FillPropertyValues(AttachedObject, AttachableObjectSettings);
			AttachedObject.DataRefType = Source.DataRefType;
			AttachedObject.Metadata = Metadata.FindByFullName(FullName);
		Else
			AttachedObject.DataRefType = MergeTypes(AttachedObject.DataRefType, Source.DataRefType);
		EndIf;
	EndDo;
	
	Return AttachedObjects;
EndFunction

// Gets integration settings of a metadata object that provides commands (a report or a data processor).
//
// Parameters:
//   FullName - String - full name of a metadata object.
//   InterfaceSettings - Arbitrary - optional. Function execution result
//       AttachableObjectsInterfaceSettings().
//
// Returns:
//   Structure - integration settings for this object.
//       Field content see at the "OnDefineSettings procedure parameters" block
//       of the AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition() procedure.
//       Additionally it contains the following fields:
//       * Kind - String - metadata object kind and name in uppercase.
//       * FullName - String - full name of a metadata object.
//       * Manager - DataProcessorManager, ReportManager - a metadata object manager.
//
Function AttachableObjectSettings(FullName, InterfaceSettings = Undefined) Export
	NameParts = StrSplit(FullName, ".");
	If NameParts.Count() <> 2 Then
		Return Undefined;
	EndIf;
	KindInCase = Upper(NameParts[0]);
	Name = NameParts[1];
	If KindInCase = "REPORT" Then
		Node = Reports;
	ElsIf KindInCase = "DATAPROCESSOR" Then
		Node = DataProcessors;
	Else
		Return Undefined;
	EndIf;
	
	If InterfaceSettings = Undefined Then
		InterfaceSettings = AttachableObjectsInterfaceSettings();
	EndIf;
	
	Settings = New Structure;
	For Each Setting In InterfaceSettings Do
		If Setting.AttachableObjectsKinds = ""
			Or StrFind(Upper(Setting.AttachableObjectsKinds), KindInCase) > 0 Then
			Settings.Insert(Setting.Key, Setting.TypeDescription.AdjustValue());
		EndIf;
	EndDo;
	
	Manager = Node[Name];
	Try
		Manager.OnDefineSettings(Settings);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось прочитать настройки объекта %1 из модуля менеджера:'; en = 'Cannot read settings of the %1 object from the manager module:'; pl = 'Nie udało się przeczytać ustawienia obiektu %1 z modułu menedżera:';es_ES = 'No se ha podido leer los ajustes del objeto %1 del módulo del gestor:';es_CO = 'No se ha podido leer los ajustes del objeto %1 del módulo del gestor:';tr = 'Yönetici modülünden nesne ""%1"" ayarları okunamıyor:';it = 'Impossibile leggere le impostazioni dell''oggetto %1 dal modulo del gestore:';de = 'Es war nicht möglich, die Objekteinstellungen %1 aus dem Manager-Modul zu lesen:'"), FullName);
		ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(
			NStr("ru = 'Подключаемые команды'; en = 'Attachable commands'; pl = 'Podłączane polecenia';es_ES = 'Comandos conectados';es_CO = 'Comandos conectados';tr = 'Bağlanabilir komutlar';it = 'Comandi collegabili';de = 'Plug-in-Befehle'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.FindByFullName(FullName),
			FullName,
			ErrorText);
		Return Undefined;
	EndTry;
	
	Settings.Insert("Kind",       KindInCase);
	Settings.Insert("FullName", FullName);
	Settings.Insert("Manager",  Manager);
	Return Settings;
EndFunction

// Adds types to array.
//
// Parameters:
//   Array - Array - a type array.
//   TypeOrTypesDetails - Type, TypesDetails - types being added.
//
Procedure SupplyTypesArray(Array, TypeOrTypeDetails) Export
	If TypeOf(TypeOrTypeDetails) = Type("TypeDescription") Then
		CommonClientServer.SupplementArray(Array, TypeOrTypeDetails.Types(), True);
	ElsIf TypeOf(TypeOrTypeDetails) = Type("Type") AND Array.Find(TypeOrTypeDetails) = Undefined Then
		Array.Add(TypeOrTypeDetails);
	EndIf;
EndProcedure

// Registers a metadata object in the tree of command sources, as well as secondary metadata objects 
//   attached to the specified metadata object.
//
// Parameters:
//   MetadataObject - MetadataObject - a metadata object to which command sources are attached.
//   Sources - ValueTree - see the details of similarly named AttachableCommandsOverridable.
//       OnDefineCommandsAttachedToObject() procedure parameter.
//   AttachedObjects - ValueTable - see the details of the AttachableCommands.
//       AttachableCommandsTable() function return value.
//   InterfaceSettings - Structure - optional. See the details of the AttachableCommands.
//       AttachableObjectsInterfaceSettings() function return value.
//
// Returns:
//   ValueTreeRow - metadata object settings. See details of parameter 2 of the   
//       AttachableCommandsOverridable.OnDefineCommandsAttachedToObject() procedure.
//
Function RegisterSource(MetadataObject, Sources, AttachedObjects, InterfaceSettings) Export
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	FullName = MetadataObject.FullName();
	Manager  = Common.ObjectManagerByFullName(FullName);
	If Manager = Undefined Then
		Return Undefined; // The object cannot be a source of commands.
	EndIf;
	
	Source = Sources.Rows.Add();
	Source.Metadata          = MetadataObject;
	Source.FullName           = FullName;
	Source.Manager            = Manager;
	Source.MetadataRef    = Common.MetadataObjectID(FullName);
	Source.Kind                 = Upper(StrSplit(FullName, ".")[0]);
	Source.IsDocumentJournal = (Source.Kind = "DOCUMENTJOURNAL");
	
	If Source.IsDocumentJournal Then
		TypesArray = New Array;
		For Each DocumentMetadata In MetadataObject.RegisteredDocuments Do
			Document = RegisterSource(DocumentMetadata, Source, AttachedObjects, InterfaceSettings);
			If Document <> Undefined Then
				TypesArray.Add(Document.DataRefType);
			EndIf;
		EndDo;
		Source.DataRefType = New TypeDescription(TypesArray);
	ElsIf Not Metadata.DataProcessors.Contains(MetadataObject) AND Not Metadata.Reports.Contains(MetadataObject) Then
		Source.DataRefType = Type(Source.Kind + "Ref." + MetadataObject.Name);
	EndIf;
	
	AttachedObjects(Source, AttachedObjects, InterfaceSettings);
	
	Return Source;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Templates.

// The information template of metadata objects that are command sources.
//
// Returns:
//   See details of parameter 2 of the   AttachableCommandsOverridable.OnDefineCommandsAttachedToObject() procedure.
//
Function CommandsSourcesTree() Export
	Result = New ValueTree;
	Result.Columns.Add("Metadata");
	Result.Columns.Add("FullName", New TypeDescription("String"));
	Result.Columns.Add("Manager");
	Result.Columns.Add("MetadataRef");
	Result.Columns.Add("DataRefType");
	Result.Columns.Add("Kind", New TypeDescription("String"));
	Result.Columns.Add("IsDocumentJournal", New TypeDescription("Boolean"));
	Return Result;
EndFunction

// Information template of reports and data processors attached to command sources.
//
// Returns:
//   ValueTable - secondary parameters.
//       * FullName  - String           - a full object name. For example: "Document.DocumentName".
//       * Manager   - Arbitrary     - an object manager module.
//       * Placement - Array           - a list of objects, to which a report or data processor is attached.
//       * DataRefType - Type, TypesDetails - a type of objects, to which a report or a data processor is attached.
//
Function AttachableObjectsTable(InterfaceSettings = Undefined) Export
	If InterfaceSettings = Undefined Then
		InterfaceSettings = AttachableObjectsInterfaceSettings();
	EndIf;
	Table = New ValueTable;
	Table.Columns.Add("FullName", New TypeDescription("String"));
	Table.Columns.Add("Manager");
	Table.Columns.Add("Metadata");
	Table.Columns.Add("DataRefType");
	
	For Each Setting In InterfaceSettings Do
		Try
			Table.Columns.Add(Setting.Key, Setting.TypeDescription);
		Except
			ErrorText = NStr("ru = 'Не удалось зарегистрировать настройку программного интерфейса подключаемых объектов.
				|Ключ: ""%1"", описание типов: ""%2"", описание ошибки: ""%3"".'; 
				|en = 'Cannot register setting of attachable objects application interface. 
				|Key: ""%1"", type description: ""%2"", error details: ""%3"".'; 
				|pl = 'Nie można zarejestrować ustawienia interfejsu aplikacji obiektów dołączanych.
				|Klucz: ""%1"", opis typów: ""%2"", opis błędu: ""%3"".';
				|es_ES = 'No se ha podido registrar el ajuste de la interfaz de programa de los objetos conectados.
				|Clave: ""%1"", descripción de los tipos: ""%2"", descripción del error: ""%3"".';
				|es_CO = 'No se ha podido registrar el ajuste de la interfaz de programa de los objetos conectados.
				|Clave: ""%1"", descripción de los tipos: ""%2"", descripción del error: ""%3"".';
				|tr = 'Bağlanan nesnelerin program arayüz ayarı kaydedilemedi. 
				| Anahtar: ""%1"", tür açıklaması: ""%2"", hata açıklaması: ""%3"".';
				|it = 'Impossibile registrare l''impostazione dell''interfaccia dell''applicazione degli oggetti allegabili.
				|Chiave: ""%1"", descrizione tipo: ""%2"", dettagli errore: ""%3"".';
				|de = 'Die Einstellung der Anwendungsschnittstelle für anhängbare Objekte kann nicht registriert werden.
				|Schlüssel: ""%1"", Typbeschreibung: ""%2"", Fehlerdetails: ""%3"".'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorText,
				Setting.Key,
				String(Setting.TypeDescription),
				BriefErrorDescription(ErrorInfo()));
			Raise ErrorText;
		EndTry;
	EndDo;
	
	Table.Indexes.Add("FullName");
	
	Return Table;
EndFunction

// Information template of reports and data processors attached to command sources.
//
// Returns:
//   ValueTable - a Settings parameter details of the OnDefineSettings procedure of objects included 
//       into the AttachableReportsAndDataProcessors subsystem content.
//       * Key             - String        - a setting name.
//       * TypesDetails    - TypesDetails - a setting type.
//       * AttachableObjectsKinds - String - a metadata object kind in uppercase.
//                                            For example, REPORT or DATA PROCESSOR.
//
Function AttachableObjectsInterfaceSettings() Export
	Table = New ValueTable;
	Table.Columns.Add("Key", New TypeDescription("String"));
	Table.Columns.Add("TypeDescription", New TypeDescription("TypeDescription"));
	Table.Columns.Add("AttachableObjectsKinds", New TypeDescription("String"));
	
	Setting = Table.Add();
	Setting.Key          = "Placement";
	Setting.TypeDescription = New TypeDescription("Array");
	Setting.AttachableObjectsKinds = "Report, DataProcessor";
	
	SSLSubsystemsIntegration.OnDefineAttachableObjectsSettingsComposition(Table);
	
	AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition(Table);
	
	Return Table;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = False;
	Handler.SharedData                  = True;
	Handler.HandlerManagement      = False;
	Handler.ExecutionMode              = "Seamless";
	Handler.Version    = "*";
	Handler.Procedure = "AttachableCommands.ConfigurationCommonDataNonexclusiveUpdate";
	Handler.Priority = 90;
EndProcedure

// Update handler for caches associated with extensions.
Function OnFillAllExtensionsParameters() Export
	Return CommonDataNonexclusiveUpdate(Type("CatalogRef.ExtensionObjectIDs"));
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// OnCreateAtServer form cache.

// Cache of the form, where attachable commands will be displayed.
Function FormCache(FormName, SourcesCommaSeparated, IsObjectForm) Export
	Commands = CommandsTable();
	Sources = CommandsSourcesTree();
	InterfaceSettings = AttachableObjectsInterfaceSettings();
	AttachedObjects = AttachableObjectsTable(InterfaceSettings);
	
	FormCache = New Structure;
	FormCache.Insert("Commands", Commands);
	FormCache.Insert("HasVisibilityConditions", False);
	FormCache.Insert("FunctionalOptions", New Structure);
	
	FormMetadata = Metadata.FindByFullName(FormName);
	ParentMetadata = ?(FormMetadata = Undefined, Undefined, FormMetadata.Parent());
	KindInCase = Upper(StrSplit(FormName, ".")[0]);
	SourcesTypes = New Array;
	If SourcesCommaSeparated = "" Then
		Source = RegisterSource(ParentMetadata, Sources, AttachedObjects, InterfaceSettings);
		SupplyTypesArray(SourcesTypes, Source.DataRefType);
	Else
		SourcesFullNames = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SourcesCommaSeparated, ",", True, True);
		For Each FullName In SourcesFullNames Do
			MetadataObject = Metadata.FindByFullName(FullName);
			Source = RegisterSource(MetadataObject, Sources, AttachedObjects, InterfaceSettings);
			SupplyTypesArray(SourcesTypes, Source.DataRefType);
		EndDo;
	EndIf;
	
	If IsObjectForm = True AND SourcesTypes.Count() = 1 AND ParentMetadata <> Metadata.FindByType(SourcesTypes[0]) Then
		IsObjectForm = False; // Object form has a list of another object type.
	EndIf;
	
	If IsObjectForm = Undefined Then
		If SourcesTypes.Count() > 1 Then
			IsObjectForm = False;
		ElsIf ParentMetadata <> Undefined Then
			Collection = New Structure("DefaultListForm, DefaultObjectForm");
			FillPropertyValues(Collection, ParentMetadata);
			If FormMetadata = Collection.DefaultListForm Then
				IsObjectForm = False;
			ElsIf FormMetadata = Collection.DefaultObjectForm AND ParentMetadata <> Metadata.FindByType(SourcesTypes[0]) Then
				IsObjectForm = True;
			Else
				If KindInCase = Upper("DocumentJournal") Then
					IsObjectForm = False;
				ElsIf KindInCase = Upper("DataProcessor") Then
					IsObjectForm = False;
				Else
					IsObjectForm = True;
				EndIf;
			EndIf;
		Else
			IsObjectForm = False;
		EndIf;
	EndIf;
	FormCache.Insert("IsObjectForm", IsObjectForm);
	
	Context = New Structure;
	Context.Insert("KindInCase", KindInCase);
	Context.Insert("FormName", FormName);
	Context.Insert("FormMetadata", FormMetadata);
	Context.Insert("SourcesTypes", SourcesTypes);
	Context.Insert("IsObjectForm", IsObjectForm);
	Context.Insert("FunctionalOptions", FormCache.FunctionalOptions);
	
	SSLSubsystemsIntegration.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	AttachableCommandsOverridable.OnDefineCommandsAttachedToObject(Context, Sources, AttachedObjects, Commands);
	
	// Filtering commands by form names and functional options.
	NameParts = StrSplit(FormName, ".");
	ShortFormName = NameParts[NameParts.UBound()];
	Count = Commands.Count();
	For Number = 1 To Count Do
		Command = Commands[Count - Number];
		// Default values.
		If Command.ChangesSelectedObjects = Undefined Then
			Command.ChangesSelectedObjects = False;
		EndIf;
		
		// Filter by purpose.
		If Command.Purpose = "ForList" AND Context.IsObjectForm Or Command.Purpose = "ForObject" AND Not Context.IsObjectForm Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		
		// Filter by form names.
		VisibilityInForms = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Upper(Command.VisibilityInForms), ",", True, True);
		If VisibilityInForms.Count() > 0
			AND VisibilityInForms.Find(Upper(ShortFormName)) = Undefined
			AND VisibilityInForms.Find(Upper(FormName)) = Undefined Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		// Filter by functional options.
		FunctionalOptions = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Command.FunctionalOptions, ",", True, True);
		CommandVisibility = FunctionalOptions.Count() = 0;
		For Each OptionName In FunctionalOptions Do
			If GetFunctionalOption(TrimAll(OptionName)) Then
				CommandVisibility = True;
				Break;
			EndIf;
		EndDo;
		If Not CommandVisibility Then
			Commands.Delete(Command);
			Continue;
		EndIf;
		// Dynamic applied visibility conditions.
		If TypeOf(Command.ParameterType) = Type("Type") Then
			TypesArray = New Array;
			TypesArray.Add(Command.ParameterType);
			Command.ParameterType = New TypeDescription(TypesArray);
		EndIf;
		If TypeOf(Command.ParameterType) = Type("TypeDescription") AND ValueIsFilled(Command.ParameterType) Then
			HasAtLeastOneType = False;
			For Each Type In SourcesTypes Do
				If Command.ParameterType.ContainsType(Type) Then
					HasAtLeastOneType = True;
				Else
					Command.HasVisibilityConditions = True;
				EndIf;
			EndDo;
			If Not HasAtLeastOneType Then
				Commands.Delete(Command);
				Continue;
			EndIf;
		EndIf;
		If TypeOf(Command.VisibilityConditions) = Type("Array") AND Command.VisibilityConditions.Count() > 0 Then
			Command.HasVisibilityConditions = True;
		EndIf;
		If Command.MultipleChoice = Undefined Then
			Command.MultipleChoice = True;
		EndIf;
		Command.ImportanceOrder = ?(Command.Importance = "Important", 1, ?(Command.Importance = "SeeAlso", 3, 2));
		FormCache.HasVisibilityConditions = FormCache.HasVisibilityConditions Or Command.HasVisibilityConditions;
		
		If IsBlankString(Command.ID) Then
			Command.ID = "Auto_" + Common.CheckSumString(Command.Manager + "/" + Command.FormName + "/" + Command.Handler);
		EndIf;
	EndDo;
	
	Return FormCache;
EndFunction

Function CommandsKinds()
	Kinds = New ValueTable;
	Kinds.Columns.Add("Name", New TypeDescription("String"));
	Kinds.Columns.Add("SubmenuName", New TypeDescription("String"));
	Kinds.Columns.Add("Title", New TypeDescription("String"));
	Kinds.Columns.Add("Order", New TypeDescription("Number"));
	Kinds.Columns.Add("Picture"); // Picture, Undefined.
	Kinds.Columns.Add("Representation"); // ButtonRepresentation, Undefined.
	Kinds.Columns.Add("FormGroupType");
	
	// A kind with a blank group for commands that are to be placed in the command bar.
	Kind = Kinds.Add();
	Kind.Name = "CommandBar";
	Kind.SubmenuName = "";
	Kind.Order    = 90;
	
	SSLSubsystemsIntegration.OnDefineAttachableCommandsKinds(Kinds);
	
	AttachableCommandsOverridable.OnDefineAttachableCommandsKinds(Kinds);
	
	Kinds.Sort("Order Asc");
	
	Return Kinds;
EndFunction

Procedure CheckCommandsKindName(KindName)
	Structure = New Structure;
	Try
		Structure.Insert(KindName, Undefined);
	Except
		ErrorText = NStr("ru = 'Имя вида команд ""%1"" не удовлетворяет требованиям именования переменных.'; en = 'The ""%1"" command kind name does not satisfy variable naming requirements.'; pl = 'Nazwa rodzaju poleceń ""%1"" nie odpowiada wymaganiom mianowania zmiennych.';es_ES = 'Nombre del tipo de comandos ""%1"" no satisfecha a los requerimientos de renombrar los variables.';es_CO = 'Nombre del tipo de comandos ""%1"" no satisfecha a los requerimientos de renombrar los variables.';tr = '""%1"" komut türü adı değişkenleri isimlendirme şartlarına uygun değil.';it = 'Il nome del tipo di comando ""%1"" non soddisfa i requisiti di denominazione della variabile.';de = 'Der Name des Befehlstyps ""%1"" erfüllt nicht die Anforderungen für die Benennung von Variablen.'");
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorText, KindName);
	EndTry;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Output.

// Places attached commands in the form.
//
// Parameters:
//   Form - ClientApplicationForm - a form, where the commands are to be placed.
//
Procedure OutputCommand(Form, Commands, PlacementParameters)
	Items = Form.Items;
	GroupsPrefix = ?(ValueIsFilled(PlacementParameters.GroupsPrefix), PlacementParameters.GroupsPrefix, "");
	CommandBar = PlacementParameters.CommandBar;
	If CommandBar = Undefined Then
		CommandBar = Items.Find(GroupsPrefix + "AttachableCommands");
		If CommandBar = Undefined Then
			CommandBar = Items.Find(GroupsPrefix + "CommandBar");
			If CommandBar = Undefined Then
				CommandBar = Items.Find(GroupsPrefix + "MainCommandBar");
				If CommandBar = Undefined AND ValueIsFilled(GroupsPrefix) Then
					FormTable = Items.Find(GroupsPrefix);
					If TypeOf(FormTable) = Type("FormTable") Then
						CommandBar = FormTable.CommandBar;
					EndIf;
				EndIf;
				If Not PlacementParameters.IsObjectForm
					AND CommandBar = Undefined
					AND Not ValueIsFilled(GroupsPrefix) Then
					FormTable = Items.Find("List");
					If TypeOf(FormTable) = Type("FormTable")
						AND FormTable.CommandBarLocation <> FormItemCommandBarLabelLocation.None Then
						CommandBar = FormTable.CommandBar;
					EndIf;
				EndIf;
				If CommandBar = Undefined Then
					CommandBar = Form.CommandBar;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	InfoOnAllSubmenus = New ValueTable;
	InfoOnAllSubmenus.Columns.Add("Popup");
	InfoOnAllSubmenus.Columns.Add("CommandsShown", New TypeDescription("Number"));
	InfoOnAllSubmenus.Columns.Add("HasCommandsWithVisibilityConditions", New TypeDescription("Boolean"));
	InfoOnAllSubmenus.Columns.Add("HasCommandsWithoutVisibilityConditions", New TypeDescription("Boolean"));
	InfoOnAllSubmenus.Columns.Add("Folders", New TypeDescription("Structure"));
	InfoOnAllSubmenus.Columns.Add("DefaultGroup");
	InfoOnAllSubmenus.Columns.Add("LastCommand");
	InfoOnAllSubmenus.Columns.Add("CommandsWithVisibilityConditions", New TypeDescription("Array"));
	SubmenuInfoQuickSearch = New Map;
	
	// Creation and initial filling of the AttachableCommandsParameters form attribute if it is missing.
	Structure = New Structure("AttachableCommandsParameters", Null);
	FillPropertyValues(Structure, Form);
	ClientParameters = Structure.AttachableCommandsParameters;
	If TypeOf(ClientParameters) <> Type("Structure") Then
		If ClientParameters = Null Then
			AttributesToAdd = New Array;
			AttributesToAdd.Add(New FormAttribute("AttachableCommandsParameters", New TypeDescription));
			Form.ChangeAttributes(AttributesToAdd);
		EndIf;
		ClientParameters = New Structure;
		ClientParameters.Insert("HasVisibilityConditions", PlacementParameters.HasVisibilityConditions);
		ClientParameters.Insert("SubmenuWithVisibilityConditions", New Array);
		ClientParameters.Insert("RootSubmenuAndCommands", New Array);
		ClientParameters.Insert("CommandsAvailability", True);
		ClientParameters.Insert("CommandsTableAddress", Undefined);
		Form.AttachableCommandsParameters = ClientParameters;
	Else
		ClientParameters.HasVisibilityConditions = ClientParameters.HasVisibilityConditions Or PlacementParameters.HasVisibilityConditions;
	EndIf;
	RootSubmenuAndCommands = ClientParameters.RootSubmenuAndCommands;
	
	// Commands output.
	Commands.Sort("Kind, ImportanceOrder Asc, Order Asc, Presentation Asc");
	CommandsCounterWithAutonaming = 0;
	CommandsKinds = CommandsKinds();
	For Each CommandsKind In CommandsKinds Do
		CheckCommandsKindName(CommandsKind.Name);
		KindCommands = Commands.FindRows(New Structure("Kind", CommandsKind.Name));
		Count = KindCommands.Count();
		If Count = 0 Then
			Continue;
		EndIf;
		
		SubmenuNameByDefault = "";
		If Not IsBlankString(CommandsKind.SubmenuName) Then
			SubmenuNameByDefault = GroupsPrefix + CommandsKind.SubmenuName;
		EndIf;
		
		SubmenuInfoByDefault = SubmenuInfoQuickSearch.Get(Lower(SubmenuNameByDefault));
		If SubmenuInfoByDefault = Undefined Then
			SubmenuInfoByDefault = RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuNameByDefault, CommandsKind, CommandBar);
			SubmenuInfoQuickSearch.Insert(Lower(SubmenuNameByDefault), SubmenuInfoByDefault);
		EndIf;
		
		For Each Command In KindCommands Do
			If IsBlankString(Command.Popup) Then
				CommandSubmenuInfo = SubmenuInfoByDefault;
			Else
				SubmenuName = GroupsPrefix + Command.Popup;
				CommandSubmenuInfo = SubmenuInfoQuickSearch.Get(Lower(SubmenuName));
				If CommandSubmenuInfo = Undefined Then
					CommandSubmenuInfo = RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuName, , , SubmenuInfoByDefault);
					SubmenuInfoQuickSearch.Insert(Lower(SubmenuName), CommandSubmenuInfo);
				EndIf;
			EndIf;
			
			FormGroup = Undefined;
			If Not ValueIsFilled(Command.Importance)
				Or Not CommandSubmenuInfo.Folders.Property(Command.Importance, FormGroup) Then
				FormGroup = CommandSubmenuInfo.DefaultGroup;
			EndIf;
			
			Command.NameOnForm = DefineCommandName(Form, FormGroup.Name, Command.ID, CommandsCounterWithAutonaming);
			
			RootItemName = ?(CommandsKind.Name = "CommandBar", Command.NameOnForm, CommandSubmenuInfo.Popup.Name);
			If RootSubmenuAndCommands.Find(RootItemName) = Undefined Then
				RootSubmenuAndCommands.Add(RootItemName);
			EndIf;
			
			FormCommand = Form.Commands.Add(Command.NameOnForm);
			FormCommand.Action = "Attachable_ExecuteCommand";
			FormCommand.Title = Command.Presentation;
			FormCommand.ToolTip   = FormCommand.Title;
			FormCommand.Representation = ?(ValueIsFilled(Command.ButtonRepresentation),
				Command.ButtonRepresentation, ButtonRepresentation.PictureAndText);
			If TypeOf(Command.Picture) = Type("Picture") Then
				FormCommand.Picture = Command.Picture;
			EndIf;
			If TypeOf(Command.Shortcut) = Type("Shortcut") Then
				FormCommand.Shortcut = Command.Shortcut;
			EndIf;
			If CommandSubmenuInfo.Popup = CommandBar
				AND StrLen(Command.Presentation) > 35
				AND ValueIsFilled(FormCommand.Picture) Then
				FormCommand.Representation = ButtonRepresentation.Picture;
			EndIf;
			
			FormButton = Items.Add(Command.NameOnForm, Type("FormButton"), FormGroup);
			FormButton.Type = FormButtonType.CommandBarButton;
			FormButton.CommandName = Command.NameOnForm;
			
			If Command.ChangesSelectedObjects AND Form.ReadOnly Then
				FormButton.Enabled = False;
			EndIf;
			
			CommandSubmenuInfo.CommandsShown = CommandSubmenuInfo.CommandsShown + 1;
			CommandSubmenuInfo.LastCommand = FormCommand;
			If Command.HasVisibilityConditions Then
				CommandSubmenuInfo.HasCommandsWithVisibilityConditions = True;
				CommandInfo = New Structure("NameOnForm, ParameterType, VisibilityConditions");
				FillPropertyValues(CommandInfo, Command);
				CommandSubmenuInfo.CommandsWithVisibilityConditions.Add(CommandInfo);
			Else
				CommandSubmenuInfo.HasCommandsWithoutVisibilityConditions = True;
			EndIf;
		EndDo;
	EndDo;
	
	// The cap command is always required.
	CapCommand = Form.Commands.Find("OutputToEmptySubmenuCommand");
	If CapCommand = Undefined Then
		CapCommand = Form.Commands.Add("OutputToEmptySubmenuCommand");
		CapCommand.Title = NStr("ru = '(нет)'; en = '(no)'; pl = '(nie ma)';es_ES = '(no)';es_CO = '(no)';tr = '(yok)';it = '(no)';de = '(nein)'");
	EndIf;
	
	// Used submenu post-processing.
	For Each SubmenuInfo In InfoOnAllSubmenus Do
		If SubmenuInfo.CommandsShown = 0 Then
			Continue;
		EndIf;
		IsCommandBar = (SubmenuInfo.Popup = CommandBar);
		FormCommand = SubmenuInfo.LastCommand;
		Submenu = SubmenuInfo.Popup;
		
		If Not IsCommandBar Then
			If SubmenuInfo.CommandsShown = 1 AND FormCommand <> Undefined Then
				// Submenu turns to button when 1 command with a short title is displayed.
				If Not ValueIsFilled(FormCommand.Picture) AND Submenu.Type = FormGroupType.Popup Then
					FormCommand.Picture = Submenu.Picture;
				EndIf;
				If StrLen(FormCommand.Title) <= 35 AND Submenu.Representation <> ButtonRepresentation.Picture Then
					FormCommand.Representation = ButtonRepresentation.PictureAndText;
				Else
					FormCommand.Representation = ButtonRepresentation.Picture;
				EndIf;
				Submenu.Type = FormGroupType.ButtonGroup;
				FormCommand.ToolTip = FormCommand.Title;
			Else
				// Adding cap buttons that are shown when all commands are hidden in the submenu.
				CapCommandName = Submenu.Name + "Stub";
				If Items.Find(CapCommandName) = Undefined Then
					FormButton = Items.Add(CapCommandName, Type("FormButton"), Submenu);
					FormButton.Type = FormButtonType.CommandBarButton;
					FormButton.CommandName  = "OutputToEmptySubmenuCommand";
					FormButton.Visible   = False;
					FormButton.Enabled = False;
				EndIf;
			EndIf;
		EndIf;
		
		If SubmenuInfo.HasCommandsWithVisibilityConditions Then
			SubmenuShortInfo = New Structure("Name, CommandsWithVisibilityConditions, HasCommandsWithoutVisibilityConditions");
			FillPropertyValues(SubmenuShortInfo, SubmenuInfo);
			SubmenuShortInfo.Name = SubmenuInfo.Popup.Name;
			ClientParameters.SubmenuWithVisibilityConditions.Add(SubmenuShortInfo);
		EndIf;
	EndDo;
	
	If ClientParameters.CommandsTableAddress <> Undefined AND IsTempStorageURL(ClientParameters.CommandsTableAddress) Then
		EarlierAddedCommands = GetFromTempStorage(ClientParameters.CommandsTableAddress);
		If TypeOf(EarlierAddedCommands) = Type("ValueTable") Then
			Index = -1;
			For Each TableRow In EarlierAddedCommands Do
				Index = Index + 1;
				FillPropertyValues(Commands.Insert(Index), TableRow);
			EndDo;
		EndIf;
		DeleteFromTempStorage(ClientParameters.CommandsTableAddress);
	EndIf;
	ClientParameters.CommandsTableAddress = PutToTempStorage(Commands, Form.UUID);
	
EndProcedure

Function RegisterSubmenu(Items, InfoOnAllSubmenus, SubmenuName, NewSubmenuTemplate = Undefined, CommandBar = Undefined, SubmenuByDefault = Undefined)
	CommandsShown = 0;
	Groups = New Structure;
	If ValueIsFilled(SubmenuName) Then
		Submenu = Items.Find(SubmenuName);
		If Submenu = Undefined Then
			If NewSubmenuTemplate = Undefined Then
				Return SubmenuByDefault;
			EndIf;
			Submenu = Items.Add(SubmenuName, Type("FormGroup"), CommandBar);
			Submenu.Type         = ?(ValueIsFilled(NewSubmenuTemplate.FormGroupType), NewSubmenuTemplate.FormGroupType, FormGroupType.Popup);
			Submenu.Title   = NewSubmenuTemplate.Title;
			If Submenu.Type = FormGroupType.Popup Then
				Submenu.Picture    = NewSubmenuTemplate.Picture;
				Submenu.Representation = NewSubmenuTemplate.Representation;
			EndIf;
		Else
			DefaultGroup = Submenu;
			CommandsShown = GroupCommandsCount(DefaultGroup);
			For Each Folder In Submenu.ChildItems Do
				If TypeOf(Folder) <> Type("FormGroup") Then
					Continue;
				EndIf;
				ShortName = Folder.Name;
				If StrStartsWith(Lower(ShortName), Lower(SubmenuName)) Then
					ShortName = Mid(ShortName, StrLen(SubmenuName) + 1);
					If Lower(ShortName) = Lower("Ordinary") Then
						DefaultGroup = Folder;
					EndIf;
				EndIf;
				Groups.Insert(ShortName, Folder);
			EndDo;
		EndIf;
		
		If Not Groups.Property("Important") Then
			GroupImportant = Items.Add(SubmenuName + "Important", Type("FormGroup"), Submenu);
			GroupImportant.Type = FormGroupType.ButtonGroup;
			GroupImportant.Title = Submenu.Title + " (" + NStr("ru = 'Важное'; en = 'Important'; pl = 'Ważne';es_ES = 'Importante';es_CO = 'Importante';tr = 'Önemli';it = 'Importante';de = 'Wichtig'") + ")";
			Groups.Insert("Important", GroupImportant);
		EndIf;
		If Not Groups.Property("Ordinary") Then
			DefaultGroup = Items.Add(SubmenuName + "Ordinary", Type("FormGroup"), Submenu);
			DefaultGroup.Type = FormGroupType.ButtonGroup;
			DefaultGroup.Title = Submenu.Title + " (" + NStr("ru = 'Обычное'; en = 'Standard'; pl = 'Standardowy';es_ES = 'Estándar';es_CO = 'Estándar';tr = 'Standart';it = 'Standard';de = 'Standard'") + ")";
			Groups.Insert("Ordinary", DefaultGroup);
		EndIf;
		If Not Groups.Property("SeeAlso") Then
			GroupSeeAlso = Items.Add(SubmenuName + "SeeAlso", Type("FormGroup"), Submenu);
			GroupSeeAlso.Type = FormGroupType.ButtonGroup;
			GroupSeeAlso.Title = Submenu.Title + " (" + NStr("ru = 'См. также'; en = 'See also:'; pl = 'Patrz także';es_ES = 'Ver también';es_CO = 'Ver también';tr = 'Ayrıca bakınız';it = 'Guarda anche:';de = 'Siehe auch'") + ")";
			Groups.Insert("SeeAlso", GroupSeeAlso);
		EndIf;
		
	Else
		If NewSubmenuTemplate = Undefined Then
			Return SubmenuByDefault;
		EndIf;
		Submenu = CommandBar;
		DefaultGroup = CommandBar;
	EndIf;
	
	Result = InfoOnAllSubmenus.Add();
	Result.Popup = Submenu;
	Result.DefaultGroup = DefaultGroup;
	Result.Folders = Groups;
	Result.CommandsShown = CommandsShown;
	Return Result;
EndFunction

Function GroupCommandsCount(Folder)
	Result = 0;
	For Each Item In Folder.ChildItems Do
		If TypeOf(Item) = Type("FormGroup") Then
			Result = Result + GroupCommandsCount(Item);
		ElsIf TypeOf(Item) = Type("FormButton") Then
			Result = Result + 1;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function DefineCommandName(Form, NameOfGroup, CommandID, CommandsCounterWithAutonaming)
	If NameMeetPropertyNamingRequirements(CommandID) Then
		CommandName = NameOfGroup + "_" + CommandID;
	Else
		CommandsCounterWithAutonaming = CommandsCounterWithAutonaming + 1;
		CommandName = NameOfGroup + "_" + Format(CommandsCounterWithAutonaming, "NZ=; NG=");
	EndIf;
	While Form.Items.Find(CommandName) <> Undefined
		Or Form.Commands.Find(CommandName) <> Undefined Do
		CommandsCounterWithAutonaming = CommandsCounterWithAutonaming + 1;
		CommandName = NameOfGroup + "_" + Format(CommandsCounterWithAutonaming, "NZ=; NG=");
	EndDo;
	Return CommandName;
EndFunction

Function NameMeetPropertyNamingRequirements(Name)
	Letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	Numbers = "1234567890";
	
	If Name = "" Or StrFind(Letters + "_", Upper(Left(Name, 1))) = 0 Then
		Return False;
	EndIf;
	
	Return StrSplit(Upper(Name), Letters + Numbers + "_", False).Count() = 0;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

Function ConfigurationCommonDataNonexclusiveUpdate() Export
	Return CommonDataNonexclusiveUpdate(Type("CatalogRef.MetadataObjectIDs"));
EndFunction

// Updates cache Objects metadata specified type.
//
// Parameters:
//   FilterByIDsType - * - a metadata object type.
//       - CatalogRef.MetadataObjectsIDs - update configuration cache.
//           Structure with the "AttachedObjects" key is written to the AttachableCommandsParameters constant.
//       - CatalogRef.ExtensionObjectsIDs - update cache of extensions.
//           Structure with the "AttachedObjects" key is written to the ExtensionVersionParameters register.
//
// Returns:
//   Structure - details
//       * HasChanges - Boolean - True if there were changes made during the update.
//       * AttachedObjects - Map - cache to quickly define a list of objects attached to 
//           configuration objects.
//           Keys and values are extension and configuration metadata object references.
//
Function CommonDataNonexclusiveUpdate(FilterByIDType)
	Result = New Structure;
	Result.Insert("HasChanges", False);
	
	If FilterByIDType = Type("CatalogRef.ExtensionObjectIDs")
		AND Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return Result;
	EndIf;
	
	AttachedObjects = New Map;
	InterfaceSettings = AttachableObjectsInterfaceSettings();
	
	Composition = Metadata.Subsystems.AttachableReportsAndDataProcessors.Content;
	For Each VendorMetadataObject In Composition Do
		If Not Common.SeparatedDataUsageAvailable() AND VendorMetadataObject.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		
		AttachedMORef = Common.MetadataObjectID(VendorMetadataObject);
		If TypeOf(AttachedMORef) <> FilterByIDType Then
			Continue;
		EndIf;
		FullName = VendorMetadataObject.FullName();
		Settings = AttachableObjectSettings(FullName, InterfaceSettings);
		If Settings = Undefined Then
			Continue;
		EndIf;
		For Each MetadataObject In Settings.Placement Do
			MORef = Common.MetadataObjectID(MetadataObject);
			DestinationArray = AttachedObjects[MORef];
			If DestinationArray = Undefined Then
				DestinationArray = New Array;
				AttachedObjects.Insert(MORef, DestinationArray);
			EndIf;
			If DestinationArray.Find(FullName) = Undefined Then
				DestinationArray.Add(FullName);
			EndIf;
		EndDo;
	EndDo;
	
	If FilterByIDType = Type("CatalogRef.MetadataObjectIDs") Then
		PreviousValue = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName());
	ElsIf FilterByIDType = Type("CatalogRef.ExtensionObjectIDs") Then
		PreviousValue = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName());
	Else
		Return Result;
	EndIf;
	
	NewValue = New Structure("AttachedObjects", AttachedObjects);
	If Not Common.DataMatch(PreviousValue, NewValue) Then
		Result.HasChanges = True;
		If FilterByIDType = Type("CatalogRef.MetadataObjectIDs") Then
			StandardSubsystemsServer.SetApplicationParameter(FullSubsystemName(), NewValue);
		ElsIf FilterByIDType = Type("CatalogRef.ExtensionObjectIDs") Then
			StandardSubsystemsServer.SetExtensionParameter(FullSubsystemName(), NewValue);
		EndIf;
	EndIf;
	
	Result.Insert("AttachedObjects", AttachedObjects);
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Calls from the ServerCall modules.

// Returns command details by form item name.
Function CommandDetails(CommandNameInForm, SettingsAddress) Export
	Commands = GetFromTempStorage(SettingsAddress);
	Command = Commands.Find(CommandNameInForm, "NameOnForm");
	If Command = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Сведения о команде ""%1"" не найдены.'; en = 'Information on the ""%1"" command is not found.'; pl = 'Informacje o poleceniu ""%1"" nie znaleziono.';es_ES = 'La información del comando ""%1"" no encontrada.';es_CO = 'La información del comando ""%1"" no encontrada.';tr = '""%1"" grup bilgileri bulunamadı.';it = 'Informazioni sul comando ""%1"" non sono state trovate.';de = 'Informationen zum Befehl ""%1"" nicht gefunden.'"),
			CommandNameInForm);
	EndIf;
	CommandDetails = Common.ValueTableRowToStructure(Command);
	
	If ValueIsFilled(CommandDetails.FormName) Then
		CommandDetails.Insert("Server", False);
		SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(CommandDetails.FormName, ".", True, True);
		SubstringCount = SubstringsArray.Count();
		If SubstringCount = 1
			Or (SubstringCount = 2 AND Upper(SubstringsArray[0]) <> "COMMONFORM") Then
			CommandDetails.FormName = CommandDetails.Manager + "." + CommandDetails.FormName;
		EndIf;
	Else
		CommandDetails.Insert("Server", True);
		If ValueIsFilled(CommandDetails.Handler) Then
			If Not IsBlankString(CommandDetails.Manager) AND StrFind(CommandDetails.Handler, ".") = 0 Then
				CommandDetails.Handler = CommandDetails.Manager + "." + CommandDetails.Handler;
			EndIf;
			If StrStartsWith(Upper(CommandDetails.Handler), Upper("CommonModule.")) Then
				PointPosition = StrFind(CommandDetails.Handler, ".");
				CommandDetails.Handler = Mid(CommandDetails.Handler, PointPosition + 1);
			EndIf;
			SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(CommandDetails.Handler, ".", True, True);
			SubstringCount = SubstringsArray.Count();
			If SubstringCount = 2 Then
				ModuleName = SubstringsArray[0];
				ModuleCommonMetadataObject = Metadata.CommonModules.Find(ModuleName);
				If ModuleCommonMetadataObject = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Общий модуль ""%1"" не найден.'; en = 'Common module ""%1"" is not found.'; pl = 'Nie znaleziono wspólnego modułu ""%1"".';es_ES = 'Módulo común ""%1"" no se ha encontrado.';es_CO = 'Módulo común ""%1"" no se ha encontrado.';tr = 'Ortak modül ""%1"" bulunamadı.';it = 'Il modulo comune""%1"" non è stato trovato.';de = 'Gemeinsames Modul ""%1"" wurde nicht gefunden.'"),
						ModuleName);
				EndIf;
				If ModuleCommonMetadataObject.ClientManagedApplication Then
					CommandDetails.Server = False;
				EndIf;
			Else
				Kind = Upper(SubstringsArray[0]);
				KindInPlural = MetadataObjectKindInPlural(Kind);
				If KindInPlural <> Undefined Then
					SubstringsArray.Set(0, KindInPlural);
					CommandDetails.Handler = StrConcat(SubstringsArray, ".");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	CommandDetails.Delete("Manager");
	
	Return New FixedStructure(CommandDetails);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with metadata objects.

// Returns the type of the object in plural.
Function MetadataObjectKindInPlural(Val Kind)
	Kind = Upper(TrimAll(Kind));
	If Kind = "EXCHANGEPLAN" Then
		Return "ExchangePlans";
	ElsIf Kind = "CATALOG" Then
		Return "Catalogs";
	ElsIf Kind = "DOCUMENT" Then
		Return "Documents";
	ElsIf Kind = "DOCUMENTJOURNAL" Then
		Return "DocumentJournals";
	ElsIf Kind = "ENUM" Then
		Return "Enums";
	ElsIf Kind = "REPORT" Then
		Return "Reports";
	ElsIf Kind = "DATAPROCESSOR" Then
		Return "DataProcessors";
	ElsIf Kind = "CHARTOFCHARACTERISTICTYPES" Then
		Return "ChartsOfCharacteristicTypes";
	ElsIf Kind = "CHARTOFACCOUNTS" Then
		Return "ChartsOfAccounts";
	ElsIf Kind = "CHARTOFCALCULATIONTYPES" Then
		Return "ChartsOfCalculationTypes";
	ElsIf Kind = "INFORMATIONREGISTER" Then
		Return "InformationRegisters";
	ElsIf Kind = "ACCUMULATIONREGISTER" Then
		Return "AccumulationRegisters";
	ElsIf Kind = "ACCOUNTINGREGISTER" Then
		Return "AccountingRegisters";
	ElsIf Kind = "CALCULATIONREGISTER" Then
		Return "CalculationRegisters";
	ElsIf Kind = "RECALCULATION" Then
		Return "Recalculations";
	ElsIf Kind = "BUSINESSPROCESS" Then
		Return "BusinessProcesses";
	ElsIf Kind = "TASK" Then
		Return "Tasks";
	ElsIf Kind = "CONSTANT" Then
		Return "Constants";
	ElsIf Kind = "SEQUENCE" Then
		Return "Sequences";
	Else
		Return Undefined;
	EndIf;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Templates.

// Attachable commands table template.
//
// Returns:
//   ValueTable - a table with attachable commands.
//        See details of parameter 4 (Commands) of the   AttachableCommandsOverridable.
//        OnDefineCommandsAttachedToObject() procedure.
//
Function CommandsTable()
	Table = New ValueTable;
	Table.Columns.Add("Kind", New TypeDescription("String"));
	Table.Columns.Add("ID", New TypeDescription("String"));
	// Appearance settings:
	Table.Columns.Add("Presentation", New TypeDescription("String"));
	Table.Columns.Add("Popup", New TypeDescription("String"));
	Table.Columns.Add("Importance", New TypeDescription("String"));
	Table.Columns.Add("Order", New TypeDescription("Number"));
	Table.Columns.Add("Picture"); // Picture.
	Table.Columns.Add("Shortcut"); // Shortcut.
	Table.Columns.Add("ButtonRepresentation");
	// Visibility and availability settings:
	Table.Columns.Add("ParameterType"); // TypesDetails.
	Table.Columns.Add("VisibilityInForms", New TypeDescription("String"));
	Table.Columns.Add("Purpose", New TypeDescription("String"));
	Table.Columns.Add("FunctionalOptions", New TypeDescription("String"));
	Table.Columns.Add("VisibilityConditions", New TypeDescription("Array"));
	Table.Columns.Add("ChangesSelectedObjects"); // Boolean or Undefined.
	// Execution process settings:
	Table.Columns.Add("MultipleChoice"); // Boolean or Undefined.
	Table.Columns.Add("WriteMode", New TypeDescription("String"));
	Table.Columns.Add("FilesOperationsRequired", New TypeDescription("Boolean"));
	// Handler settings:
	Table.Columns.Add("Manager", New TypeDescription("String"));
	Table.Columns.Add("Handler", New TypeDescription("String"));
	Table.Columns.Add("AdditionalParameters", New TypeDescription("Structure"));
	Table.Columns.Add("FormName", New TypeDescription("String"));
	Table.Columns.Add("FormParameters"); // Structure or Undefined.
	Table.Columns.Add("FormParameterName", New TypeDescription("String"));
	// Service:
	Table.Columns.Add("ImportanceOrder", New TypeDescription("Number"));
	Table.Columns.Add("NameOnForm", New TypeDescription("String"));
	Table.Columns.Add("HasVisibilityConditions", New TypeDescription("Boolean"));
	Return Table;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other.

// Returns a full subsystem name.
Function FullSubsystemName() Export
	Return "StandardSubsystems.AttachableCommands";
EndFunction

Function MergeTypes(Type1, Type2)
	Type1IsTypesDetails = TypeOf(Type1) = Type("TypeDescription");
	Type2IsTypesDetails = TypeOf(Type2) = Type("TypeDescription");
	If Type1IsTypesDetails AND Type1.Types().Count() > 0 Then
		SourceTypesDetails = Type1;
		TypesToAdd = ?(Type2IsTypesDetails, Type2.Types(), ValueToArray(Type2));
	ElsIf Type2IsTypesDetails AND Type2.Types().Count() > 0 Then
		SourceTypesDetails = Type2;
		TypesToAdd = ValueToArray(Type1);
	ElsIf TypeOf(Type1) <> Type("Type") Then
		Return Type2;
	ElsIf TypeOf(Type2) <> Type("Type") Then
		Return Type1;
	Else
		Types = New Array;
		Types.Add(Type1);
		Types.Add(Type2);
		Return New TypeDescription(Types);
	EndIf;
	If TypesToAdd.Count() = 0 Then
		Return SourceTypesDetails;
	Else
		Return New TypeDescription(SourceTypesDetails, TypesToAdd);
	EndIf;
EndFunction

Function ValueToArray(Value)
	Result = New Array;
	Result.Add(Value);
	Return Result;
EndFunction

Function SpecifyCommandsSources(FullMetadataObjectName)
	MetadataObjectKind = Lower(StrSplit(FullMetadataObjectName, ".")[0]);
	Return MetadataObjectKind = Lower("ExternalDataProcessor")
		Or MetadataObjectKind = Lower("ExternalReport")
		Or MetadataObjectKind = Lower("DataProcessor")
		Or MetadataObjectKind = Lower("Report")
		Or MetadataObjectKind = Lower("CommonForm");
EndFunction

#EndRegion