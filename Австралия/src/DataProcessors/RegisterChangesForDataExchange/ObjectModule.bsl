#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ObjectsEnabledByOption Export;

#EndRegion

#Region Public

// Returns a value tree that contains data required to select a node. The tree has two levels:
// exchange plan -> exchange nodes. Internal nodes are not included in the tree.
//
// Parameters:
//    DataObject - AnyRef, Structure - a reference or a structure that contains record set dimensions. 
//                   Data to analyze exchange nodes. If DataObject is not specified, all metadata objects are used.
//    TableName   - String - if DataObject is a structure, then the table name is for  records set.
//
// Returns:
//    ValueTree with the following columns:
//        * Description                  - String - presentation of exchange plan or exchange node.
//        * PictureIndex                - Number - 1 = exchange plan 2 = node 3 = node marked for deletion.
//        * AutoRecordPictureIndex - Number  - if the DataObject parameter is not specified, it is Undefined.
//                                                   Else: 0 = none, 1 = prohibited, 2 = enabled, 
//                                                   Undefined for the exchange plan.
//        * ExchangePlanName                 - String - Node exchange plan.
//        * Ref                        - ExchangePlanRef - a node reference, Undefined for the exchange plan.
//        * Code                           - Number, String - Node code, Undefined for exchange plan.
//        * SentNo            - Number - node data.
//        * ReceivedMessageNumber                - Number - node data.
//        * MessageNumber                - Number, NULL   - if an object is specified, then the message number is for it, else NULL.
//        * NotExported                 - Boolean, Null - if an object is specified, it is an export flag, else NULL.
//        * Mark                       - Boolean       - if object is specified, 0 = no registration, 
//                                                         1 = there is a registration, else it is always 0.
//        * InitialMark               - Boolean       - similar to the Mark column.
//        * RowID           - Number        - index of the added row (the tree is iterated from top 
//                                                         to bottom from left to right).
//
Function GenerateNodeTree(DataObject = Undefined, TableName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Rows  = Tree.Rows;
	
	Columns.Add("Description");
	Columns.Add("PictureIndex");
	Columns.Add("AutoRecordPictureIndex");
	Columns.Add("ExchangePlanName");
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("SentNo");
	Columns.Add("ReceivedNo");
	Columns.Add("MessageNo");
	Columns.Add("NotExported");
	Columns.Add("Check");
	Columns.Add("InitialMark");
	Columns.Add("RowID");
	
	Query = New Query;
	If DataObject = Undefined Then
		MetaObject = Undefined;
		QueryText = "
			|SELECT
			|	REFPRESENTATION(Ref) AS Description,
			|	CASE 
			|		WHEN DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""            AS ExchangePlanName,
			|	Code                AS Code,
			|	Ref             AS Ref,
			|	SentNo AS SentNo,
			|	ReceivedNo     AS ReceivedNo,
			|	NULL               AS MessageNo,
			|	NULL               AS NotExported,
			|	0                  AS NodeChangeCount
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|WHERE
			|	NOT ExchangePlan.ThisNode
			|";
		
	Else
		If TypeOf(DataObject) = Type("Structure") Then
			QueryText = "";
			For Each KeyValue In DataObject Do
				CurName = KeyValue.Key;
				QueryText = QueryText + "
					|AND ChangesTable." + CurName + " = &" + CurName;
				Query.SetParameter(CurName, DataObject[CurName]);
			EndDo;
			CurTableName = TableName;
			MetaObject    = MetadataByFullName(TableName);
			
		ElsIf TypeOf(DataObject) = Type("String") Then
			QueryText  = "";
			CurTableName = DataObject;
			MetaObject    = MetadataByFullName(DataObject);
			
		Else
			QueryText = "
				|AND ChangesTable.Ref = &RegistrationObject";
			Query.SetParameter("RegistrationObject", DataObject);
			
			MetaObject    = DataObject.Metadata();
			CurTableName = MetaObject.FullName();
		EndIf;
		
		QueryText = "
			|SELECT
			|	REFPRESENTATION(ExchangePlan.Ref) AS Description,
			|	CASE 
			|		WHEN ExchangePlan.DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""                         AS ExchangePlanName,
			|	ExchangePlan.Code                  AS Code,
			|	ExchangePlan.Ref               AS Ref,
			|	ExchangePlan.SentNo   AS SentNo,
			|	ExchangePlan.ReceivedNo       AS ReceivedNo,
			|	ChangesTable.MessageNo AS MessageNo,
			|	CASE 
			|		WHEN ChangesTable.MessageNo IS NULL
			|		THEN TRUE
			|		ELSE FALSE
			|	END AS NotExported,
			|	COUNT(ChangesTable.Node) AS NodeChangeCount
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|LEFT JOIN
			|	" + CurTableName + ".Changes AS ChangesTable
			|ON
			|	ChangesTable.Node = ExchangePlan.Ref
			|	" + QueryText + "
			|WHERE
			|	NOT ExchangePlan.ThisNode
			|GROUP BY 
			|	ExchangePlan.Ref, 
			|	ChangesTable.MessageNo
			|";
	EndIf;
	
	CurLineNumber = 0;
	For Each Meta In Metadata.ExchangePlans Do
		
		If Not AccessRight("Read", Meta) Then
			Continue;
		EndIf;
	
		PlanName = Meta.Name;
		AutoRegistration = Undefined;
		If MetaObject <> Undefined Then
			CompositionItem = Meta.Content.Find(MetaObject);
			If CompositionItem = Undefined Then
				// The object is not included in the current exchange plan.
				Continue;
			EndIf;
			AutoRegistration = ?(CompositionItem.AutoRecord = AutoChangeRecord.Deny, 1, 2);
		EndIf;
		
		PlanName = Meta.Name;
		Query.Text = StrReplace(QueryText, "{0}", PlanName);
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			PlanRow = Rows.Add();
			PlanRow.Description   = Meta.Presentation();
			PlanRow.PictureIndex = 0;
			PlanRow.ExchangePlanName  = PlanName;
			
			PlanRow.RowID = CurLineNumber;
			CurLineNumber = CurLineNumber + 1;
			
			// Sorting by presentation cannot be applied in a query.
			TemporaryTable = Result.Unload();
			TemporaryTable.Sort("Description");
			For Each NodeRow In TemporaryTable Do;
				NewRow = PlanRow.Rows.Add();
				FillPropertyValues(NewRow, NodeRow);
				
				NewRow.InitialMark = ?(NodeRow.NodeChangeCount > 0, 1, 0);
				NewRow.Check         = NewRow.InitialMark;
				
				NewRow.AutoRecordPictureIndex = AutoRegistration;
				
				NewRow.RowID = CurLineNumber;
				CurLineNumber = CurLineNumber + 1;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return Tree;
EndFunction

// Returns a structure that describes exchange plan metadata.
// Objects that are not included in an exchange plan, to be excluded.
//
// Parameters:
//    ExchangePlanName - String           - name of the exchange plan metadata that is used to generate a configuration tree.
//                   - ExchangePlanRef - the configuration tree is generated for its exchange plan.
//                   - Undefined     - the tree of all configuration is generated.
//
// Returns:
//    Structure - metadata description. Fields:
//         * NamesStructure              - Structure - Key - metadata group (constants, catalogs and 
//                                                    so on), value is an array of full names.
//         * PresentationsStructure     - Structure - Key - metadata group (constants, catalogs and 
//                                                    so on), value is an array of full names.
//         * AutoRecordStructure   - Structure - Key - metadata group (constants, catalogs and so 
//                                                    on), value is an array of autorecord flags on the node.
//         * ChangesCount        - Undefined - needed for further calculation.
//         * ExportedCount - Undefined - needed for further calculation.
//         * NotExportedCount - Undefined - needed for further calculation.
//         * ChangeCountString - Undefined - needed for further calculation.
//         * Tree                     - ValueTree - contains the following columns:
//               ** Description        - String - object metadata kind presentation.
//               ** MetaFullName       - String - the full metadata object name.
//               ** PictureIndex      - Number  - depends on metadata.
//               ** Mark             - Undefined - it is further used to store marks.
//               ** RowID - Number  - index of the added row (the tree is iterated from top to bottom from left to right).
//               ** AutoRecord     - Boolean - if ExchangePlanName is specified, the parameter can contain the following values (for leaves): 1 - allowed,
//                                                 2-prohibited. Else Undefined.
//
Function GenerateMetadataStructure(ExchangePlanName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Columns.Add("Description");
	Columns.Add("MetaFullName");
	Columns.Add("PictureIndex");
	Columns.Add("Check");
	Columns.Add("RowID");
	
	Columns.Add("AutoRegistration");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	Columns.Add("ChangeCountString");
	
	// Root
	RootRow = Tree.Rows.Add();
	RootRow.Description = Metadata.Presentation();
	RootRow.PictureIndex = 0;
	RootRow.RowID = 0;
	
// Parameters:
	CurParameters = New Structure();
	CurParameters.Insert("NamesStructure", New Structure);
	CurParameters.Insert("PresentationStructure", New Structure);
	CurParameters.Insert("AutoRecordStructure", New Structure);
	CurParameters.Insert("Rows", RootRow.Rows);
	
	If ExchangePlanName = Undefined Then
		ExchangePlan = Undefined;
	ElsIf TypeOf(ExchangePlanName) = Type("String") Then
		ExchangePlan = Metadata.ExchangePlans[ExchangePlanName];
	Else
		ExchangePlan = ExchangePlanName.Metadata();
	EndIf;
	CurParameters.Insert("ExchangePlan", ExchangePlan);
	
	// For DIB exchange plans metadata objects that are not included to the corresponding ORM 
	// subscriptions (objects that are exported only as a part of the initial image) are excluded from 
	// items available to be registered.
	If ExchangePlan <> Undefined
		AND ExchangePlan.DistributedInfoBase
		AND ConfigurationSupportsSSL Then
		
		ORMSubscriptionsComposition = New Array;
		
		For Each Subscription In Metadata.EventSubscriptions Do
			
			If Not StrStartsWith(Subscription.Name, ExchangePlan.Name)
				And Not StrEndsWith(Subscription.Name, "Registration") Then
				Continue;
			EndIf;
			
			For Each SourceType In Subscription.Source.Types() Do
				SourceMetadata = Metadata.FindByType(SourceType);
				If ORMSubscriptionsComposition.Find(SourceMetadata) = Undefined Then
					ORMSubscriptionsComposition.Add(SourceMetadata);
				EndIf;
			EndDo;
			
		EndDo;
		
		CurParameters.Insert("ORMSubscriptionsComposition", ORMSubscriptionsComposition);
	EndIf;
	
	Result = New Structure();
	Result.Insert("Tree", Tree);
	Result.Insert("NamesStructure", CurParameters.NamesStructure);
	Result.Insert("PresentationStructure", CurParameters.PresentationStructure);
	Result.Insert("AutoRecordStructure", CurParameters.AutoRecordStructure);

	CurLineNumber = 1;
	GenerateMetadataLevel(CurLineNumber, CurParameters, 1,  2,  False,   "Constants",               NStr("ru = 'Константы'; en = 'Constants'; pl = 'Stałe';es_ES = 'Constantes';es_CO = 'Constantes';tr = 'Sabitler';it = 'Costanti';de = 'Konstanten'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 3,  4,  True, "Catalogs",             NStr("ru = 'Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 5,  6,  True, "Sequences",      NStr("ru = 'Последовательности'; en = 'Sequences'; pl = 'Porządkowy';es_ES = 'Secuencias';es_CO = 'Secuencias';tr = 'Sıralar';it = 'Sequenze';de = 'Sequenzen'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 7,  8,  True, "Documents",               NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 9,  10, True, "ChartsOfCharacteristicTypes", NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 11, 12, True, "ChartsOfAccounts",             NStr("ru = 'Планы счетов'; en = 'Charts of accounts'; pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planları';it = 'Piani dei conti';de = 'Kontenpläne'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 13, 14, True, "ChartsOfCalculationTypes",       NStr("ru = 'Планы видов расчета'; en = 'Charts of calculation types'; pl = 'Plany typów obliczeń';es_ES = 'Diagramas de los tipos de cálculos';es_CO = 'Diagramas de los tipos de cálculos';tr = 'Hesaplama türleri çizelgeleri';it = 'Grafici di tipi di calcolo';de = 'Diagramme der Berechnungstypen'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 15, 16, True, "InformationRegisters",        NStr("ru = 'Регистры сведений'; en = 'Information registers'; pl = 'Rejestry informacji';es_ES = 'Registros de información';es_CO = 'Registros de información';tr = 'Bilgi kayıtları';it = 'Registri informazioni';de = 'Informationen registriert'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 17, 18, True, "AccumulationRegisters",      NStr("ru = 'Регистры накопления'; en = 'Accumulation registers'; pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulación';es_CO = 'Registros de acumulación';tr = 'Birikim kayıtları';it = 'Registri di accumulo';de = 'Akkumulationsregister'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 19, 20, True, "AccountingRegisters",     NStr("ru = 'Регистры бухгалтерии'; en = 'Accounting registers'; pl = 'Rejestry księgowe';es_ES = 'Registros de contabilidad';es_CO = 'Registros de contabilidad';tr = 'Muhasebe kayıtları';it = 'Registri contabili';de = 'Buchhaltungsregister'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 21, 22, True, "CalculationRegisters",         NStr("ru = 'Регистры расчета'; en = 'Calculation registers'; pl = 'Rejestry obliczeń';es_ES = 'Registros de cálculos';es_CO = 'Registros de cálculos';tr = 'Hesaplama kayıtları';it = 'Registri di calcolo';de = 'Berechnungsregister'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 23, 24, True, "BusinessProcesses",          NStr("ru = 'Бизнес-процессы'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'İş süreçleri';it = 'Processi di business';de = 'Geschäftsprozesse'"));
	GenerateMetadataLevel(CurLineNumber, CurParameters, 25, 26, True, "Tasks",                  NStr("ru = 'Задач'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'Görevler';it = 'Compiti';de = 'Aufgaben'"));
	
	Return Result;
EndFunction

// Calculates the number of changes in metadata objects for an exchange node.
//
// Parameters:
//     TableList - Array - names. Can be a key/value collection where values are name arrays.
//     NodesList  - ExchangePlanRef, Array - nodes.
//
// Returns:
//     ValueTable - columns:
//         * MetaFullName           - String - a full name of metadata that needs the number calculated.
//         * ExchangeNode              - ExchangePlanRef - a reference to an exchange node for which the count is calculated.
//         * ChangesCount     - Number - contains the overall count of changes.
//         * ExportedCount - Number - contains the number of exported changes.
//         * NotExportedCount - Number - contains the number of not exported changes.
//
Function GetChangeCount(TableList, NodesList) Export
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("MetaFullName");
	Columns.Add("ExchangeNode");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	
	Result.Indexes.Add("MetaFullName");
	Result.Indexes.Add("ExchangeNode");
	
	Query = New Query;
	Query.SetParameter("NodesList", NodesList);
	
	// TableList can contain an array, structure, or map that contains multiple arrays.
	If TableList = Undefined Then
		Return Result;
	ElsIf TypeOf(TableList) = Type("Array") Then
		Source = New Structure("_", TableList);
	Else
		Source = TableList;
	EndIf;
	
	// Reading data in portions, each portion contains 200 tables processed in a query.
	Text = "";
	Number = 0;
	For Each KeyValue In Source Do
		If TypeOf(KeyValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		For Each Item In KeyValue.Value Do
			If IsBlankString(Item) Then
				Continue;
			EndIf;
			
			If Not AccessRight("Read", Metadata.FindByFullName(Item)) Then
				Continue;
			EndIf;
			
			Text = Text + ?(Text = "", "", "UNION ALL") + " 
				|SELECT 
				|	""" + Item + """ AS MetaFullName,
				|	Node                AS ExchangeNode,
				|	COUNT(*)              AS ChangeCount,
				|	COUNT(MessageNo) AS ExportedCount,
				|	COUNT(*) - COUNT(MessageNo) AS NotExportedCount
				|FROM
				|	" + Item + ".Changes
				|WHERE
				|	Node IN (&NodesList)
				|GROUP BY
				|	Node
				|";
				
			Number = Number + 1;
			If Number = 200	Then
				Query.Text = Text;
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					FillPropertyValues(Result.Add(), Selection);
				EndDo;
				Text = "";
				Number = 0;
			EndIf;
			
		EndDo;
	EndDo;
	
	// Reading unread
	If Text <> "" Then
		Query.Text = Text;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			FillPropertyValues(Result.Add(), Selection);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Returns a metadata object by full name. An empty string means the whole configuration.
//
// Parameters:
//    MetadataName - String - a metadata object name, for example, "Catalog.Currencies" or "Constants".
//
// Returns:
//    MetadataObject - search result.
//
Function MetadataByFullName(MetadataName) Export
	
	If IsBlankString(MetadataName) Then
		// Whole configuration
		Return Metadata;
	EndIf;
		
	Value = Metadata.FindByFullName(MetadataName);
	If Value = Undefined Then
		Value = Metadata[MetadataName];
	EndIf;
	
	Return Value;
EndFunction

// Returns the object registration flag on the node.
//
// Parameters:
//    Node - ExchangePlanRef - an exchange plan node for which we receive information,
//    RegistrationObject - String, AnyRef, Structure - an object whose data is analyzed.
//                        The structure contains change values of record set dimensions.
//    TableName        - String - if RegistrationObject is a structure, then contains a table name for dimensions set.
//
// Returns:
//    Boolean - the result of the registration.
//
Function ObjectRegisteredForNode(Node, RegistrationObject, TableName = Undefined) Export
	ParameterType = TypeOf(RegistrationObject);
	If ParameterType = Type("String") Then
		// Constant as a metadata
		Details = MetadataCharacteristics(RegistrationObject);
		CurrentObject = Details.Manager.CreateValueManager();
		
	ElsIf ParameterType = Type("Structure") Then
		// Dimensions set, TableName - that.
		Details = MetadataCharacteristics(TableName);
		CurrentObject = Details.Manager.CreateRecordSet();
		For Each KeyValue In RegistrationObject Do
			CurrentObject.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		
	Else
		CurrentObject = RegistrationObject;
	EndIf;
	
	Return ExchangePlans.IsChangeRecorded(Node, CurrentObject);
EndFunction

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AdditionalReportsAndDataProcessors

// Internal for registration in data processors to be attached.
//
// Returns:
//     Structure - contains info about data processor.
//
Function ExternalDataProcessorInfo() Export
	
	Info = New Structure;
	
	Info.Insert("Kind",             "RelatedObjectsCreation");
	Info.Insert("Commands",         New ValueTable);
	Info.Insert("SafeMode", True);
	Info.Insert("Purpose",      New Array);
	
	Info.Insert("Description", NStr("ru = 'Регистрация изменений для обмена данными'; en = 'Data staging manager'; pl = 'Menedżer rejestrowania danych';es_ES = 'Fecha de registro del gerente';es_CO = 'Fecha de registro del gerente';tr = 'Veri hazırlama yöneticisi';it = 'Responsabile data staging';de = 'Datenaufbereitungsmanager'"));
	Info.Insert("Version",       "1.0");
	Info.Insert("SSLVersion",    "1.2.1.4");
	Info.Insert("Information",    NStr("ru = 'Обработка для управления регистрацией объектов на узлах обмена до формирования выгрузки. При работе в составе конфигурации с БСП версии 2.1.2.0 и старше производит контроль ограничений миграции данных для узлов обмена.'; en = 'Data processor to manage object registration on exchange nodes before export generating. When using configuration with SL version 2.1.2.0 and higher, data processor controls data migration limitations for the exchange nodes.'; pl = 'Przetwarzanie danych do zarządzania rejestracją obiektów na węzłach wymiany przed wygenerowaniem eksportu. Podczas korzystania z konfiguracji w wersji SL 2.1.2.0 oraz nowszej przetwarzanie danych kontroluje ograniczenia migracji danych dla węzłów wymiany.';es_ES = 'Procesador de datos para gestionar el registro de objetos en los nodos de intercambio antes de generar la exportación. Utilizando la configuración con la versión SL 2.1.2.0 o superior, el procesador de datos controla las limitaciones de migración de datos para los nodos de intercambio.';es_CO = 'Procesador de datos para gestionar el registro de objetos en los nodos de intercambio antes de generar la exportación. Utilizando la configuración con la versión SL 2.1.2.0 o superior, el procesador de datos controla las limitaciones de migración de datos para los nodos de intercambio.';tr = 'Dışa aktarma işleminden önce değişim ünitelerinde nesne kaydını yönetmek için veri işlemcisi. SL sürüm 2.1.2.0 ve üstü ile yapılandırmayı kullanırken, veri işlemcisi, değişim üniteleri için veri geçişi sınırlamalarını kontrol eder.';it = 'Processore di dati per gestire la registrazione degli oggetti sui nodi di scambio prima di generare l''esportazione. Quando si usa la configurazione con la versione SL 2.1.2.0 e superiore, il processore di dati controlla le limitazioni di migrazione dei dati per i nodi di scambio.';de = 'Datenprozessor zur Verwaltung der Objektregistrierung auf Exchange-Knoten vor dem Export. Bei Verwendung der Konfiguration mit der SL-Version 2.1.2.0 und höher steuert der Datenprozessor die Datenmigrationsbeschränkungen für die Exchange-Knoten.'"));
	
	Info.Purpose.Add("ExchangePlans.*");
	Info.Purpose.Add("Constants.*");
	Info.Purpose.Add("Catalogs.*");
	Info.Purpose.Add("Documents.*");
	Info.Purpose.Add("Sequences.*");
	Info.Purpose.Add("ChartsOfCharacteristicTypes.*");
	Info.Purpose.Add("ChartsOfAccounts.*");
	Info.Purpose.Add("ChartsOfCalculationTypes.*");
	Info.Purpose.Add("InformationRegisters.*");
	Info.Purpose.Add("AccumulationRegisters.*");
	Info.Purpose.Add("AccountingRegisters.*");
	Info.Purpose.Add("CalculationRegisters.*");
	Info.Purpose.Add("BusinessProcesses.*");
	Info.Purpose.Add("Tasks.*");
	
	Columns = Info.Commands.Columns;
	StringType = New TypeDescription("String");
	Columns.Add("Presentation", StringType);
	Columns.Add("ID", StringType);
	Columns.Add("Use", StringType);
	Columns.Add("Modifier",   StringType);
	Columns.Add("ShowNotification", New TypeDescription("Boolean"));
	
	// The only command. Determine what to do by type of the passed item.
	Command = Info.Commands.Add();
	Command.Presentation = NStr("ru = 'Редактирование регистрации изменений объекта'; en = 'Editing object change registration'; pl = 'Edytowanie rejestracji zmian obiektu';es_ES = 'Edición del registro de cambios de objetos';es_CO = 'Edición del registro de cambios de objetos';tr = 'Nesne değişiklik kaydı düzenleme';it = 'Modifica oggetto cambio registrazione';de = 'Bearbeiten des Objekts ändert Registrierung'");
	Command.ID = "OpenRegistrationEditingForm";
	Command.Use = "ClientMethodCall";
	
	Return Info;
EndFunction

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region Private

// Runs registration change according to the passed parameters.
// Parameters:
//     JobParameters - Structure - parameters to change registration.
//         * Command                 - Boolean - True if you need to add, False if you need to delete.
//         * WithoutAutoregistration - Boolean - True if you do not need to analyze the autorecord flag.
//         * Node - ExchangePlanRef - a reference to the exchange plan node.
//         * Data                  - AnyRef, String, Structure - data or data array.
//         * TableName              - String - if Data is a structure, then contains a table name.
//     StorageAddress - Arbitrary - temporary storage address to save the result on start in a background job.
//
// Returns:
//     Structure - an operation result:
//         * Total   - Number - a total object count.
//         * Done - Number - a number of objects that are processed.
//         * Command - a value of input parameter Command used to simplify results processing.
//
Function ChangeRegistration(JobParameters, StorageAddress = Undefined) Export
	TableName = Undefined;
	JobParameters.Property("TableName", TableName);
	
	ConfigurationSupportsSSL       = JobParameters.ConfigurationSupportsSSL;
	RegisterWithSSLMethodsAvailable  = JobParameters.RegisterWithSSLMethodsAvailable;
	DIBModeAvailable                 = JobParameters.DIBModeAvailable;
	ObjectExportControlSetting = JobParameters.ObjectExportControlSetting;
	
	ExecutionResult = EditRegistrationAtServer(JobParameters.Command, JobParameters.NoAutoRegistration, 
		JobParameters.Node, JobParameters.Data, TableName);
		
	If StorageAddress <> Undefined Then
		PutToTempStorage(ExecutionResult, StorageAddress);
	EndIf;
	
	Return ExecutionResult;
EndFunction

// Returns the beginning of the full form name to open by the passed object.
//
// Parameters:
//    CurrentObject - string or DynamicList whose form name is required.
// Returns:
//    String - a full name of the form.
//
Function GetFormName(CurrentObject = Undefined) Export
	
	Type = TypeOf(CurrentObject);
	If Type = Type("DynamicList") Then
		Return CurrentObject.MainTable + ".";
	ElsIf Type = Type("String") Then
		Return CurrentObject + ".";
	EndIf;
	
	Meta = ?(CurrentObject = Undefined, Metadata(), CurrentObject.Metadata());
	Return Meta.FullName() + ".";
EndFunction	

// Recursive update of hierarchy marks, which can have 3 states, in a tree row.
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure ChangeMark(RowData) Export
	RowData.Check = RowData.Check % 2;
	SetMarksForChilds(RowData);
	SetMarksForParents(RowData);
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row.
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure SetMarksForChilds(RowData) Export
	Value = RowData.Check;
	For Each Child In RowData.GetItems() Do
		Child.Check = Value;
		SetMarksForChilds(Child);
	EndDo;
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row.
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure SetMarksForParents(RowData) Export
	RowParent = RowData.GetParent();
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		For Each Child In RowParent.GetItems() Do
			AllTrue = AllTrue AND (Child.Check = 1);
			NotAllFalse = NotAllFalse Or Boolean(Child.Check);
		EndDo;
		If AllTrue Then
			RowParent.Check = 1;
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
		Else
			RowParent.Check = 0;
		EndIf;
		SetMarksForParents(RowParent);
	EndIf;
EndProcedure

// Exchange node attribute reading.
//
// Parameters:
//    Ref - ExchangePlanRef - a reference to the exchange node.
//    Data - String - a list of attribute names to read, separated by commas.
//
// Returns:
//    Structure - read data.
//
Function GetExchangeNodeParameters(Ref, Data) Export
	
	Result = New Structure(Data);
	
	Query = New Query(
	"SELECT 
	|	" + Data + "
	|FROM
	|	ExchangePlan." + DataExchangeCached.GetExchangePlanName(Ref) + "
	|WHERE
	|	Ref = &Ref");
	Query.SetParameter("Ref", Ref);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction	

// Exchange node attribute writing.
//
// Parameters:
//    Ref - ExchangePlanRef - a reference to the exchange node.
//    Data - Structure - contains node attribute values.
//
Procedure SetExchangeNodeParameters(Ref, Data) Export
	
	NodeObject = Ref.GetObject();
	If NodeObject = Undefined Then
		// Reference on deleted object.
		Return;
	EndIf;
	
	Changed = False;
	For Each Item In Data Do
		If NodeObject[Item.Key] = Item.Value Then
			Continue;
		EndIf;
		
		NodeObject[Item.Key] = Item.Value;
		Changed = True;
	EndDo;
	
	If Changed Then
		NodeObject.DataExchange.Load = True;
		NodeObject.Write();
	EndIf;
	
EndProcedure

// Returns data details by the full table name/full metadata name or metadata.
//
// Parameters:
//    - MetadataTableName - String - table name, for example "Catalog.Currencies".
//
// Returns:
//    Structure - data description as a value set. Contains the following data.
//      IsSequence - Boolean - a sequence flag.
//      IsCollection - Boolean - a value collection flag.
//      IsConstant - Boolean - a constant flag.
//      IsReference - Boolean - a flag indicating a reference data type.
//      IsSet - Boolean - a flag indicating a register record set.
//      Manager - ValueManager - table value manager.
//      TableName - String - a name of the table.
//
Function MetadataCharacteristics(MetadataTableName) Export
	
	IsSequence = False;
	IsCollection          = False;
	IsConstant          = False;
	IsReference             = False;
	IsSet              = False;
	Manager              = Undefined;
	TableName            = "";
	
	If TypeOf(MetadataTableName) = Type("String") Then
		Meta = MetadataByFullName(MetadataTableName);
		TableName = MetadataTableName;
	ElsIf TypeOf(MetadataTableName) = Type("Type") Then
		Meta = Metadata.FindByType(MetadataTableName);
		TableName = Meta.FullName();
	Else
		Meta = MetadataTableName;
		TableName = Meta.FullName();
	EndIf;
	
	If Meta = Metadata.Constants Then
		IsCollection = True;
		IsConstant = True;
		Manager     = Constants;
		
	ElsIf Meta = Metadata.Catalogs Then
		IsCollection = True;
		IsReference    = True;
		Manager      = Catalogs;
		
	ElsIf Meta = Metadata.Documents Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Documents;
		
	ElsIf Meta = Metadata.Enums Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Enums;
		
	ElsIf Meta = Metadata.ChartsOfCharacteristicTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCharacteristicTypes;
		
	ElsIf Meta = Metadata.ChartsOfAccounts Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfAccounts;
		
	ElsIf Meta = Metadata.ChartsOfCalculationTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCalculationTypes;
		
	ElsIf Meta = Metadata.BusinessProcesses Then
		IsCollection = True;
		IsReference    = True;
		Manager     = BusinessProcesses;
		
	ElsIf Meta = Metadata.Tasks Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Tasks;
		
	ElsIf Meta = Metadata.Sequences Then
		IsSet              = True;
		IsSequence = True;
		IsCollection          = True;
		Manager              = Sequences;
		
	ElsIf Meta = Metadata.InformationRegisters Then
		IsCollection = True;
		IsSet     = True;
		Manager 	 = InformationRegisters;
		
	ElsIf Meta = Metadata.AccumulationRegisters Then
		IsCollection = True;
		IsSet     = True;
		Manager     = AccumulationRegisters;
		
	ElsIf Meta = Metadata.AccountingRegisters Then
		IsCollection = True;
		IsSet     = True;
		Manager     = AccountingRegisters;
		
	ElsIf Meta = Metadata.CalculationRegisters Then
		IsCollection = True;
		IsSet     = True;
		Manager     = CalculationRegisters;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		IsConstant = True;
		Manager     = Constants[Meta.Name];
		
	ElsIf Metadata.Catalogs.Contains(Meta) Then
		IsReference = True;
		Manager  = Catalogs[Meta.Name];
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		IsReference = True;
		Manager  = Documents[Meta.Name];
		
	ElsIf Metadata.Sequences.Contains(Meta) Then
		IsSet              = True;
		IsSequence = True;
		Manager              = Sequences[Meta.Name];
		
	ElsIf Metadata.Enums.Contains(Meta) Then
		IsReference = True;
		Manager  = Enums[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		IsReference = True;
		Manager = ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCalculationTypes[Meta.Name];
		
	ElsIf Metadata.InformationRegisters.Contains(Meta) Then
		IsSet = True;
		Manager = InformationRegisters[Meta.Name];
		
	ElsIf Metadata.AccumulationRegisters.Contains(Meta) Then
		IsSet = True;
		Manager = AccumulationRegisters[Meta.Name];
		
	ElsIf Metadata.AccountingRegisters.Contains(Meta) Then
		IsSet = True;
		Manager = AccountingRegisters[Meta.Name];
		
	ElsIf Metadata.CalculationRegisters.Contains(Meta) Then
		IsSet = True;
		Manager = CalculationRegisters[Meta.Name];
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		IsReference = True;
		Manager = BusinessProcesses[Meta.Name];
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		IsReference = True;
		Manager = Tasks[Meta.Name];
		
	Else
		MetaParent = Meta.Parent();
		If MetaParent <> Undefined AND Metadata.CalculationRegisters.Contains(MetaParent) Then
			// Recalculation
			IsSet = True;
			Manager = CalculationRegisters[MetaParent.Name].Recalculations[Meta.Name];
		EndIf;
		
	EndIf;
	Result = New Structure();
	Result.Insert("TableName", TableName);
	Result.Insert("Metadata", Meta);
	Result.Insert("Manager", Manager);
	Result.Insert("IsSet", IsSet);
	Result.Insert("IsReference", IsReference);
	Result.Insert("IsConstant", IsConstant);
	Result.Insert("IsSequence", IsSequence);
	Result.Insert("IsCollection", IsCollection);
	Return Result;
	
EndFunction

// Returns a table describing dimensions for data set change record.
//
// Parameters:
//    TableName   - String - Table name, for example "Name table, for example "InformationRegister.CurrencyRates".
//    AllDimensions - Boolean - a flag showing whether all dimensions are got for the information 
//                            register, not just basic and master dimensions.
//
// Returns:
//    ValueTable - columns:
//         * Name         - String - a dimension name.
//         * ValueType - TypesDetails - types.
//         * Title   - String - dimension presentation.
//
Function RecordSetDimensions(TableName, AllDimensions = False) Export
	
	If TypeOf(TableName) = Type("String") Then
		Meta = MetadataByFullName(TableName);
	Else
		Meta = TableName;
	EndIf;
	
	// Specifying key fields
	Dimensions = New ValueTable;
	Columns = Dimensions.Columns;
	Columns.Add("Name");
	Columns.Add("ValueType");
	Columns.Add("Title");
	
	If Not AllDimensions Then
		// Data to be registered
		DontConsider = "#MessageNo#Node#";
		For Each MetaCommon In Metadata.CommonAttributes Do
			DontConsider = DontConsider + "#" + MetaCommon.Name + "#" ;
		EndDo;
		
		Query = New Query("SELECT * FROM " + Meta.FullName() + ".Changes WHERE FALSE");
		EmptyResult = Query.Execute();
		For Each ResultColumn In EmptyResult.Columns Do
			ColumnName = ResultColumn.Name;
			If StrFind(DontConsider, "#" + ColumnName + "#") = 0 Then
				Row = Dimensions.Add();
				Row.Name         = ColumnName;
				Row.ValueType = ResultColumn.ValueType;
				
				MetaDimension = Meta.Dimensions.Find(ColumnName);
				Row.Title = ?(MetaDimension = Undefined, ColumnName, MetaDimension.Presentation());
			EndIf;
		EndDo;
		
		Return Dimensions;
	EndIf;
	
	// All dimensions.
	
	IsInformationRegister = Metadata.InformationRegisters.Contains(Meta);
	
	// Recorder
	If Metadata.AccumulationRegisters.Contains(Meta)
	 Or Metadata.AccountingRegisters.Contains(Meta)
	 Or Metadata.CalculationRegisters.Contains(Meta)
	 Or (IsInformationRegister AND Meta.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate)
	 Or Metadata.Sequences.Contains(Meta) Then
		Row = Dimensions.Add();
		Row.Name         = "Recorder";
		Row.ValueType = Documents.AllRefsType();
		Row.Title   = NStr("ru = 'Регистратор'; en = 'Recorder'; pl = 'Rejestrator';es_ES = 'Registrador';es_CO = 'Registrador';tr = 'Transfer kaydı';it = 'Documento di Rif.';de = 'Recorder'");
	EndIf;
	
	// Period
	If IsInformationRegister AND Meta.MainFilterOnPeriod Then
		Row = Dimensions.Add();
		Row.Name         = "Period";
		Row.ValueType = New TypeDescription("Date");
		Row.Title   = NStr("ru = 'Период'; en = 'Period'; pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'");
	EndIf;
	
	// Dimensions
	If IsInformationRegister Then
		For Each MetaDimension In Meta.Dimensions Do
			Row = Dimensions.Add();
			Row.Name         = MetaDimension.Name;
			Row.ValueType = MetaDimension.Type;
			Row.Title   = MetaDimension.Presentation();
		EndDo;
	EndIf;
	
	// Recalculation
	If Metadata.CalculationRegisters.Contains(Meta.Parent()) Then
		Row = Dimensions.Add();
		Row.Name         = "RecalculationObject";
		Row.ValueType = Documents.AllRefsType();
		Row.Title   = NStr("ru = 'Объект перерасчета'; en = 'Object to recalculate'; pl = 'Obiekt ponownego obliczania';es_ES = 'Objeto de recálculo';es_CO = 'Objeto de recálculo';tr = 'Yeniden hesaplama nesnesi';it = 'Oggetto da ricalcolare';de = 'Neuberechnungsobjekt'");
	EndIf;
	
	Return Dimensions;
EndFunction

// Adds columns to the FormTable.
//
// Parameters:
//    FormTable   - FormItem - an item linked to an attribute. The data columns are added to this attribute.
//    СохранятьИмена - Строка - a list of column names, separated by commas.
//    Add - Array - contains structures that describe columns to be added (Name, ValueType, Title).
//    ColumnGroup - FormItem - a column group where the columns are added.
//
Procedure AddColumnsToFormTable(FormTable, SaveNames, Add, Columns_Group = Undefined) Export
	
	Form = FormItemForm(FormTable);
	FormItems = Form.Items;
	TableAttributeName = FormTable.DataPath;
	
	ToSave = New Structure(SaveNames);
	DataPathsToSave = New Map;
	For Each Item In ToSave Do
		DataPathsToSave.Insert(TableAttributeName + "." + Item.Key, True);
	EndDo;
	
	IsDynamicList = False;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = TableAttributeName AND Attribute.ValueType.ContainsType(Type("DynamicList")) Then
			IsDynamicList = True;
			Break;
		EndIf;
	EndDo;

	// If TableForm is not a dynamic list.
	If Not IsDynamicList Then
		NamesToDelete = New Array;
		
		// Deleting attributes that are not included in SaveNames.
		For Each Attribute In Form.GetAttributes(TableAttributeName) Do
			CurName = Attribute.Name;
			If Not ToSave.Property(CurName) Then
				NamesToDelete.Add(Attribute.Path + "." + CurName);
			EndIf;
		EndDo;
		
		ItemsToAdd = New Array;
		For Each Column In Add Do
			CurName = Column.Name;
			If Not ToSave.Property(CurName) Then
				ItemsToAdd.Add( New FormAttribute(CurName, Column.ValueType, TableAttributeName, Column.Title) );
			EndIf;
		EndDo;
		
		Form.ChangeAttributes(ItemsToAdd, NamesToDelete);
	EndIf;
	
	// Deleting form items
	Parent = ?(Columns_Group = Undefined, FormTable, Columns_Group);
	
	Delete = New Array;
	For Each Item In Parent.ChildItems Do
		Delete.Add(Item);
	EndDo;
	For Each Item In Delete Do
		If TypeOf(Item) <> Type("FormGroup") AND DataPathsToSave[Item.DataPath] = Undefined Then
			FormItems.Delete(Item);
		EndIf;
	EndDo;
	
	// Creating items
	Prefix = FormTable.Name;
	For Each Column In Add Do
		CurName = Column.Name;
		FormItem = FormItems.Insert(Prefix + CurName, Type("FormField"), Parent);
		FormItem.Type = FormFieldType.InputField;
		FormItem.DataPath = TableAttributeName + "." + CurName;
		FormItem.Title = Column.Title;
	EndDo;
	
EndProcedure	

// Returns a detailed object presentation.
//
// Parameters:
//    - PresentationObject - AnyRef - an object whose presentation is being retrieved.
//
// Returns:
//      String - an object presentation.
//
Function RefPresentation(ObjectToGetPresentation) Export
	
	If TypeOf(ObjectToGetPresentation) = Type("String") Then
		// Metadata
		Meta = Metadata.FindByFullName(ObjectToGetPresentation);
		Result = Meta.Presentation();
		If Metadata.Constants.Contains(Meta) Then
			Result = Result + " (constant)";
		EndIf;
		Return Result;
	EndIf;
	
	// Ref
	Result = "";
	ModuleCommon = CommonModuleCommon();
	If ModuleCommon <> Undefined Then
		Result = ModuleCommon.SubjectString(ObjectToGetPresentation);
	EndIf;
	
	If IsBlankString(Result) AND ObjectToGetPresentation <> Undefined AND Not ObjectToGetPresentation.IsEmpty() Then
		Meta = ObjectToGetPresentation.Metadata();
		If Metadata.Documents.Contains(Meta) Then
			Result = String(ObjectToGetPresentation);
		Else
			Presentation = Meta.ObjectPresentation;
			If IsBlankString(Presentation) Then
				Presentation = Meta.Presentation();
			EndIf;
			Result = String(ObjectToGetPresentation);
			If Not IsBlankString(Presentation) Then
				Result = Result + " (" + Presentation + ")";
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = NStr("ru = 'не задано'; en = 'not set'; pl = 'nie określono';es_ES = 'no definido';es_CO = 'no definido';tr = 'Belirlenmedi';it = 'non impostato';de = 'nicht gesetzt'");
	EndIf;
	
	Return Result;
EndFunction

// Returns a flag specifying whether the infobase runs in file mode.
// Returns:
//       Boolean - a flag specifying whether the infobase runs in file mode.
Function IsFileInfobase() Export
	Return StrFind(InfoBaseConnectionString(), "File=") > 0;
EndFunction

//  Reads current data from the dynamic list by its setting and returns it as a values table.
//
// Parameters:
//    - DataSource - DynamicList - a form attribute.
//
// Returns:
//      ValueTable - the current data of the dynamic list.
//
Function DynamicListCurrentData(DataSource) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	Set = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = DataSource.QueryText;
	Set.AutoFillAvailableFields = True;
	Set.DataSource = Source.Name;
	Set.Name = Source.Name;
	
	SettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(SettingsSource);
	
	CurSettings = Composer.Settings;
	
	// Selected fields
	For Each Item In CurSettings.Selection.SelectionAvailableFields.Items Do
		If Not Item.Folder Then
			Field = CurSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			Field.Use = True;
			Field.Field = Item.Field;
		EndIf;
	EndDo;
	Folder = CurSettings.Structure.Add(Type("DataCompositionGroup"));
	Folder.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));

	// Filter
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.Filter);
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.SettingsComposer.GetSettings().Filter);

	// Display
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionSchema, CurSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Toller = New DataCompositionProcessor;
	Toller.Initialize(Template);
	Output  = New DataCompositionResultValueCollectionOutputProcessor;
	
	Result = New ValueTable;
	Output.SetObject(Result); 
	Output.Output(Toller);
	
	Return Result;
EndFunction

// Reading settings from the common storage.
// Parameters:
//      SettingKey - String - a key for reading settings.
//
Procedure ReadSettings(SettingKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = CommonSettingsStorage.Load(ObjectKey);
	If TypeOf(CurrentSettings) <> Type("Map") Then
		// Default preferences
		CurrentSettings = New Map;
		CurrentSettings.Insert("RegisterRecordAutoRecordSetting",            False);
		CurrentSettings.Insert("SequenceAutoRecordSetting", False);
		CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting",      "");
		CurrentSettings.Insert("ObjectExportControlSetting",           True); // Flag of object export control
		CurrentSettings.Insert("MessageNumberOptionSetting",              0);     // First exchange execution
	EndIf;
	
	RegisterRecordAutoRecordSetting            = CurrentSettings["RegisterRecordAutoRecordSetting"];
	SequenceAutoRecordSetting = CurrentSettings["SequenceAutoRecordSetting"];
	QueryExternalDataProcessorAddressSetting      = CurrentSettings["QueryExternalDataProcessorAddressSetting"];
	ObjectExportControlSetting           = CurrentSettings["ObjectExportControlSetting"];
	MessageNumberOptionSetting             = CurrentSettings["MessageNumberOptionSetting"];

	CheckSettingCorrectness(SettingKey);
EndProcedure

// Setting SSL support flags.
//
Procedure ReadSSLSupportFlags() Export
	ConfigurationSupportsSSL = SSL_RequiredVersionAvailable();
	
	If ConfigurationSupportsSSL Then
		// Performing registration with an external registration interface.
		RegisterWithSSLMethodsAvailable = SSL_RequiredVersionAvailable("2.1.5.11");
		DIBModeAvailable                = SSL_RequiredVersionAvailable("2.1.3.25");
		AsynchronousRegistrationAvailable    = SSL_RequiredVersionAvailable("2.3.5.34");
	Else
		RegisterWithSSLMethodsAvailable = False;
		DIBModeAvailable                = False;
		AsynchronousRegistrationAvailable    = False;
	EndIf;
EndProcedure

// Writing settings to the common storage.
//
// Parameters:
//      SettingKey - String - a key for saving settings.
//
Procedure SaveSettings(SettingKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = New Map;
	CurrentSettings.Insert("RegisterRecordAutoRecordSetting",            RegisterRecordAutoRecordSetting);
	CurrentSettings.Insert("SequenceAutoRecordSetting", SequenceAutoRecordSetting);
	CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting",      QueryExternalDataProcessorAddressSetting);
	CurrentSettings.Insert("ObjectExportControlSetting",           ObjectExportControlSetting);
	CurrentSettings.Insert("MessageNumberOptionSetting",             MessageNumberOptionSetting);
	
	CommonSettingsStorage.Save(ObjectKey, "", CurrentSettings)
EndProcedure	

// Checking settings. Incorrect settings are reset.
//
// Parameters:
//      SettingKey - String - a key of setting to check.
// Returns:
//     Structure - Key - a setting name.
//                 Value - error description or Undefined.
//
Function CheckSettingCorrectness(SettingKey = "") Export
	
	Result = New Structure("HasErrors,
		|RegisterRecordAutoRecordSetting, SequenceAutoRecordSetting, 
		|QueryExternalDataProcessorAddressSetting, ObjectExportControlSetting,
		|MessageNumberOptionSetting",
		False);
		
	// Checking whether an external data processor is available.
	If IsBlankString(QueryExternalDataProcessorAddressSetting) Then
		// Setting an empty string value to the QueryExternalDataProcessorAddressSetting.
		QueryExternalDataProcessorAddressSetting = "";
		
	ElsIf Lower(Right(TrimAll(QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		// Setting an empty string value to the QueryExternalDataProcessorAddressSetting.
		QueryExternalDataProcessorAddressSetting = "";
			
	Else
		// Data processor is a part of the configuration
		If Metadata.DataProcessors.Find(QueryExternalDataProcessorAddressSetting) = Undefined Then
			Text = NStr("ru = 'Обработка ""%1"" не найдена в составе конфигурации'; en = 'The %1 data processor not found in the configuration'; pl = 'Opracowanie ""%1"" nie zostało znalezione w konfiguracji';es_ES = 'El procesador de datos ""%1"" no se ha encontrado en la configuración';es_CO = 'El procesador de datos ""%1"" no se ha encontrado en la configuración';tr = '%1 veri işlemcisi yapılandırmada bulunamadı';it = 'L''elaboratore dati %1 non è stato trovato nella configurazione';de = 'Datenprozessor ""%1"" wurde in der Konfiguration nicht gefunden'");
			Result.QueryExternalDataProcessorAddressSetting = StrReplace(Text, "%1", QueryExternalDataProcessorAddressSetting);
			
			Result.HasErrors = True;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Changes registration for a passed object.
//
// Parameters:
//     Command                 - Boolean - True if you need to add, False if you need to delete.
//     WithoutAutoregistration - Boolean - True if you do not need to analyze the autorecord flag.
//     Node - ExchangePlanRef - a reference to the exchange plan node.
//     Data                  - AnyRef, String, Structure - data or data array.
//     TableName              - String - if Data is a structure, then contains a table name.
//
// Returns:
//     Structure - an operation result:
//         * Total   - Number - a total object count.
//         * Done - Number - a number of objects that are processed.
//         * Command - a value of input parameter Command used to simplify results processing.
//
Function EditRegistrationAtServer(Command, NoAutoRegistration, Node, Data, TableName = Undefined) Export
	
	ReadSettings();
	Result = New Structure("Total, Success", 0, 0);
	
	// This flag is required only when adding registration results to the Result structure. The flag value can be True only if the configuration supports SSL.
	SSLFilterRequired = TypeOf(Command) = Type("Boolean") AND Command AND ConfigurationSupportsSSL AND ObjectExportControlSetting;
	
	If TypeOf(Data) = Type("Array") Then
		RegistrationData = Data;
	Else
		RegistrationData = New Array;
		RegistrationData.Add(Data);
	EndIf;
	
	For Each Item In RegistrationData Do
		
		Type = TypeOf(Item);
		Values = New Array;
		
		If Item = Undefined Then
			// Whole configuration
			
			If TypeOf(Command) = Type("Boolean") AND Command Then
				// Adding registration in parts.
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Constants", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Catalogs", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Documents", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Sequences", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfCharacteristicTypes", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfAccounts", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfCalculationTypes", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "InformationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "AccumulationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "AccountingRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "CalculationRegisters", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "BusinessProcesses", TableName) );
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Tasks", TableName) );
				Continue;
			EndIf;
			
			// Deleting registration with platform method.
			Values.Add(Undefined);
			
		ElsIf Type = Type("String") Then
			// It is metadata, either collection or a certain kind. Autorecord does not matter.
			Details = MetadataCharacteristics(Item);
			If SSLFilterRequired Then
				AddResults(Result, SSL_MetadataChangesRegistration(Node, Details, NoAutoRegistration) );
				Continue;
				
			ElsIf NoAutoRegistration Then
				If Details.IsCollection Then
					For Each Meta In Details.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Details.Metadata;
					CompositionItem = Node.Metadata().Content.Find(Meta);
					If CompositionItem = Undefined Then
						Continue;
					EndIf;
					// Constant?
					Values.Add(Details.Metadata);
				EndIf;
				
			Else
				// Excluding inappropriate objects.
				If Details.IsCollection Then
					// Registering metadata objects singly
					For Each Meta In Details.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Details.Metadata;
					CompositionItem = Node.Metadata().Content.Find(Meta);
					If CompositionItem = Undefined Or CompositionItem.AutoRecord <> AutoChangeRecord.Allow Then
						Continue;
					EndIf;
					// Constant?
					Values.Add(Details.Metadata);
				EndIf;
			EndIf;
			
			// Adding additional registration objects, Values[0] - specific metadata with the Item name.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration) Do
				Values.Add(CurItem);
			EndDo;
			
		ElsIf Type = Type("Structure") Then
			// It is either the specific record set or the result of selecting a reference type by filter.
			Details = MetadataCharacteristics(TableName);
			If Details.IsReference Then
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, Item.Ref) );
				Continue;
			EndIf;
			// Specific record set is passed, auto record settings do not matter.
			If SSLFilterRequired Then
				AddResults(Result, SSL_SetChangesRegistration(Node, Item, Details) );
				Continue;
			EndIf;
			
			Set = Details.Manager.CreateRecordSet();
			For Each KeyValue In Item Do
				Set.Filter[KeyValue.Key].Set(KeyValue.Value);
			EndDo;
			Values.Add(Set);
			// Adding additional registration objects.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration, TableName) Do
				Values.Add(CurItem);
			EndDo;
			
		Else
			// Specific reference is passed, auto record settings do not matter.
			If SSLFilterRequired Then
				AddResults(Result, SSL_RefChangesRegistration(Node, Item) );
				Continue;
				
			EndIf;
			Values.Add(Item);
			// Adding additional registration objects.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration) Do
				Values.Add(CurItem);
			EndDo;
			
		EndIf;
		
		// Registering objects without using a filter.
		For Each CurValue In Values Do
			ExecuteObjectRegistrationCommand(Command, Node, CurValue);
			Result.Success = Result.Success + 1;
			Result.Total   = Result.Total   + 1;
		EndDo;
		
	EndDo; // Iterating objects in the data array for registration.
	Result.Insert("Command", Command);
	Return Result;
EndFunction

//
// Copies data composition filter to existing data.
//
Procedure CopyDataCompositionFilter(DestinationGroup, SourceGroup) 
	
	SourceCollection = SourceGroup.Items;
	DestinationCollection = DestinationGroup.Items;
	For Each Item In SourceCollection Do
		ItemType  = TypeOf(Item);
		NewItem = DestinationCollection.Add(ItemType);
		
		FillPropertyValues(NewItem, Item);
		If ItemType = Type("DataCompositionFilterItemGroup") Then
			CopyDataCompositionFilter(NewItem, Item) 
		EndIf;
		
	EndDo;
	
EndProcedure

// Performs direct action with the target object.
//
Procedure ExecuteObjectRegistrationCommand(Val Command, Val Node, Val RegistrationObject)
	
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			// Registration
			If MessageNumberOptionSetting = 1 Then
				// Registering an object as a sent one
				Command = 1 + Node.SentNo;
			Else
				// Registering an object as a new one
				RecordChanges(Node, RegistrationObject);
			EndIf;
		Else
			// Canceling registration
			ExchangePlans.DeleteChangeRecords(Node, RegistrationObject);
		EndIf;
	EndIf;
	
	If TypeOf(Command) = Type("Number") Then
		// A single registration with a specified message number.
		If Command = 0 Then
			// Similarly if a new object is being registered.
			RecordChanges(Node, RegistrationObject)
		Else
			// Registering passed object changes for a passed node.
			ExchangePlans.RecordChanges(Node, RegistrationObject);
			Selection = ExchangePlans.SelectChanges(Node, Command, RegistrationObject);
			While Selection.Next() Do
				// Selecting changes to set a data exchange message number.
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RecordChanges(Val Node, Val RegistrationObject)
	
	If Not RegisterWithSSLMethodsAvailable Then
		ExchangePlans.RecordChanges(Node, RegistrationObject);
		Return;
	EndIf;
		
	// Getting a common module that contains registration handlers.
	ModuleDataExchangeEvents = CommonModuleEventDataExchange();
	
	// RegistrationObject contains a metadata object or an infobase object.
	If TypeOf(RegistrationObject) = Type("MetadataObject") Then
		Characteristics = MetadataCharacteristics(RegistrationObject);
		If Characteristics.IsReference Then
			
			Selection = Characteristics.Manager.Select();
			While Selection.Next() Do
				ModuleDataExchangeEvents.RecordDataChanges(Node, Selection.Ref, ObjectExportControlSetting);
			EndDo;
			
		ElsIf Characteristics.IsSet Then
			For Each RegisterDimension In RegistrationObject.Dimensions Do
				If Lower(RegisterDimension.Name) = "node" Then
					Return;
				EndIf;
			EndDo;
			DimensionFields = "";
			For Each Row In RecordSetDimensions(Characteristics.TableName) Do
				DimensionFields = DimensionFields + "," + Row.Name
			EndDo;
			DimensionFields = Mid(DimensionFields, 2);
			If IsBlankString(DimensionFields) Then
				// There are no dimensions with main filter in the information register.
				// All changes are registered for a metadata object.
				ExchangePlans.RecordChanges(Node, RegistrationObject);
			Else
				Query = New Query("
					|SELECT DISTINCT 
					| " + DimensionFields + "
					|FROM 
					|	" + Characteristics.TableName + "
					|");
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					Data = New Structure(DimensionFields);
					FillPropertyValues(Data, Selection);
					SSL_SetChangesRegistration(Node, Data, Characteristics);
				EndDo;
			EndIf;
		ElsIf Characteristics.IsConstant Then
			Selection = Characteristics.Manager.CreateValueManager();
			ModuleDataExchangeEvents.RecordDataChanges(Node, Selection, ObjectExportControlSetting);
		EndIf;
		Return;
	EndIf;
	
	// Common object
	ModuleDataExchangeEvents.RecordDataChanges(Node, RegistrationObject, ObjectExportControlSetting);
EndProcedure

// Returns a managed form that contains a passed form item.
//
Function FormItemForm(FormItem)
	Result = FormItem;
	FormTypes = New TypeDescription("ClientApplicationForm");
	While Not FormTypes.ContainsType(TypeOf(Result)) Do
		Result = Result.Parent;
	EndDo;
	Return Result;
EndFunction

// Internal, for generating a metadata group (for example, catalogs) in a metadata tree.
//
Procedure GenerateMetadataLevel(CurrentRowNumber, Parameters, PictureIndex, NodePictureIndex, AddSubordinate, MetaName, MetaPresentation)
	
	LevelPresentation = New Array;
	AutoRecords     = New Array;
	LevelNames         = New Array;
	
	AllRows = Parameters.Rows;
	MetaPlan  = Parameters.ExchangePlan;
	
	ORMSubscriptionsComposition = Undefined;
	CheckORMSubscriptionsContent = Parameters.Property("ORMSubscriptionsComposition", ORMSubscriptionsComposition);
	
	GroupString = AllRows.Add();
	GroupString.RowID = CurrentRowNumber;
	
	GroupString.MetaFullName  = MetaName;
	GroupString.Description   = MetaPresentation;
	GroupString.PictureIndex = PictureIndex;
	
	Rows = GroupString.Rows;
	HadSubordinate = False;
	
	For Each Meta In Metadata[MetaName] Do
		
		If MetaPlan = Undefined Then
			// An exchange plan is not specified
			
			If Not MetadataObjectAvailableByFunctionalOptions(Meta) Then
				Continue;
			EndIf;
			
			HadSubordinate = True;
			MetaFullName   = Meta.FullName();
			Description    = Meta.Presentation();
			
			If AddSubordinate Then
				
				NewString = Rows.Add();
				NewString.MetaFullName  = MetaFullName;
				NewString.Description   = Description ;
				NewString.PictureIndex = NodePictureIndex;
				
				CurrentRowNumber = CurrentRowNumber + 1;
				NewString.RowID = CurrentRowNumber;
				
			EndIf;
			
			LevelNames.Add(MetaFullName);
			LevelPresentation.Add(Description);
			
		Else
			
			Item = MetaPlan.Content.Find(Meta);
			
			If Item <> Undefined AND AccessRight("Read", Meta) Then
				
				If ConfigurationSupportsSSL
					AND CheckORMSubscriptionsContent
					AND ORMSubscriptionsComposition.Find(Meta) = Undefined Then
					Continue;
				EndIf;
				
				If Not MetadataObjectAvailableByFunctionalOptions(Meta) Then
					Continue;
				EndIf;
				
				HadSubordinate = True;
				MetaFullName   = Meta.FullName();
				Description    = Meta.Presentation();
				AutoRegistration = ?(Item.AutoRecord = AutoChangeRecord.Deny, 1, 2);
				
				If AddSubordinate Then
					
					NewString = Rows.Add();
					NewString.MetaFullName   = MetaFullName;
					NewString.Description    = Description ;
					NewString.PictureIndex  = NodePictureIndex;
					NewString.AutoRegistration = AutoRegistration;
					
					CurrentRowNumber = CurrentRowNumber + 1;
					NewString.RowID = CurrentRowNumber;
					
				EndIf;
				
				LevelNames.Add(MetaFullName);
				LevelPresentation.Add(Description);
				AutoRecords.Add(AutoRegistration);
				
			EndIf;
		EndIf;
		
	EndDo;
	
	If HadSubordinate Then
		Rows.Sort("Description");
		Parameters.NamesStructure.Insert(MetaName, LevelNames);
		Parameters.PresentationStructure.Insert(MetaName, LevelPresentation);
		If Not AddSubordinate Then
			Parameters.AutoRecordStructure.Insert(MetaName, AutoRecords);
		EndIf;
	Else
		// Deleting rows that do not match conditions.
		AllRows.Delete(GroupString);
	EndIf;
	
EndProcedure

// Determines whether the metadata object is available by functional options.
//
// Parameters:
//   MetadataObject - MetadataObject - a metadata object to be checked.
//
// Returns:
//  Boolean - True if the object is available.
//
Function MetadataObjectAvailableByFunctionalOptions(MetadataObject)
	
	If Not ValueIsFilled(ObjectsEnabledByOption) Then
		ObjectsEnabledByOption = ObjectsEnabledByOption();
	EndIf;
	
	Return ObjectsEnabledByOption[MetadataObject] <> False;
	
EndFunction

// Metadata object availability by functional options.
Function ObjectsEnabledByOption()
	
	Parameters = New Structure();
	
	ObjectsEnabled = New Map;
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		Value = -1;
		
		For Each Item In FunctionalOption.Content Do
			
			If Value = -1 Then
				Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
			EndIf;
			
			If Value = True Then
				ObjectsEnabled.Insert(Item.Object, True);
			Else
				If ObjectsEnabled[Item.Object] = Undefined Then
					ObjectsEnabled.Insert(Item.Object, False);
				EndIf;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return ObjectsEnabled;
	
EndFunction

// Accumulating registration results.
//
Procedure AddResults(Destination, Source)
	Destination.Success = Destination.Success + Source.Success;
	Destination.Total   = Destination.Total   + Source.Total;
EndProcedure	

// Returns the array of additional objects being registered according to check boxes.
//
Function GetAdditionalRegistrationObjects(RegistrationObject, AutoRecordControlNode, WithoutAutoRecord, TableName = Undefined)
	Result = New Array;
	
	// Analyzing global parameters.
	If (Not RegisterRecordAutoRecordSetting) AND (Not SequenceAutoRecordSetting) Then
		Return Result;
	EndIf;
	
	ValueType = TypeOf(RegistrationObject);
	NamePassed = ValueType = Type("String");
	If NamePassed Then
		Details = MetadataCharacteristics(RegistrationObject);
	ElsIf ValueType = Type("Structure") Then
		Details = MetadataCharacteristics(TableName);
		If Details.IsSequence Then
			Return Result;
		EndIf;
	Else
		Details = MetadataCharacteristics(RegistrationObject.Metadata());
	EndIf;
	
	MetaObject = Details.Metadata;
	
	// Collection recursively	
	If Details.IsCollection Then
		For Each Meta In MetaObject Do
			AdditionalSet = GetAdditionalRegistrationObjects(Meta.FullName(), AutoRecordControlNode, WithoutAutoRecord, TableName);
			For Each Item In AdditionalSet Do
				Result.Add(Item);
			EndDo;
		EndDo;
		Return Result;
	EndIf;
	
	// Single
	NodeContent = AutoRecordControlNode.Metadata().Content;
	
	// Documents may affect sequences and register records.
	If Metadata.Documents.Contains(MetaObject) Then
		
		If RegisterRecordAutoRecordSetting Then
			For Each Meta In MetaObject.RegisterRecords Do
				
				CompositionItem = NodeContent.Find(Meta);
				If CompositionItem <> Undefined AND (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
					If NamePassed Then
						Result.Add(Meta);
					Else
						Details = MetadataCharacteristics(Meta);
						Set = Details.Manager.CreateRecordSet();
						Set.Filter.Recorder.Set(RegistrationObject);
						Set.Read();
						Result.Add(Set);
						// Checking the passed set recursively.
						AdditionalSet = GetAdditionalRegistrationObjects(Set, AutoRecordControlNode, WithoutAutoRecord, TableName);
						For Each Item In AdditionalSet Do
							Result.Add(Item);
						EndDo;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;
		
		If SequenceAutoRecordSetting Then
			For Each Meta In Metadata.Sequences Do
				
				Details = MetadataCharacteristics(Meta);
				If Meta.Documents.Contains(MetaObject) Then
					// A sequence is being registered for a specific document type.
					CompositionItem = NodeContent.Find(Meta);
					If CompositionItem <> Undefined AND (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
						// Registering data for the current node.
						If NamePassed Then
							Result.Add(Meta);
						Else
							Set = Details.Manager.CreateRecordSet();
							Set.Filter.Recorder.Set(RegistrationObject);
							Set.Read();
							Result.Add(Set);
						EndIf;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	// Register records. may affect sequences.
	ElsIf SequenceAutoRecordSetting AND (
		Metadata.InformationRegisters.Contains(MetaObject)
		Or Metadata.AccumulationRegisters.Contains(MetaObject)
		Or Metadata.AccountingRegisters.Contains(MetaObject)
		Or Metadata.CalculationRegisters.Contains(MetaObject)) Then
		For Each Meta In Metadata.Sequences Do
			If Meta.RegisterRecords.Contains(MetaObject) Then
				// A sequence to be registered for a register record set.
				CompositionItem = NodeContent.Find(Meta);
				If CompositionItem <> Undefined AND (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
					Result.Add(Meta);
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// Converts a string value to a number value
//
// Parameters:
//     Text - String - string presentation of a number.
// 
// Returns:
//     Number        - a converted string.
//     Undefined - if a string cannot be converted.
//
Function StringToNumber(Val Text)
	NumberText = TrimAll(StrReplace(Text, Chars.NBSp, ""));
	
	If IsBlankString(NumberText) Then
		Return 0;
	EndIf;
	
	// Leading zeroes
	Position = 1;
	While Mid(NumberText, Position, 1) = "0" Do
		Position = Position + 1;
	EndDo;
	NumberText = Mid(NumberText, Position);
	
	// Checking whether there is a default result.
	If NumberText = "0" Then
		Result = 0;
	Else
		NumberType = New TypeDescription("Number");
		Result = NumberType.AdjustValue(NumberText);
		If Result = 0 Then
			// The default result was processed earlier, this is a conversion error.
			Result = Undefined;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Returns the DataExchangeEvents common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleEventDataExchange()
	If Metadata.CommonModules.Find("DataExchangeEvents") = Undefined Then
		Return Undefined;
	EndIf;
	
	// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
	Return Eval("DataExchangeEvents");
EndFunction

// Returns the StandardSubsystemsServer common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleStandardSubsystemsServer()
	If Metadata.CommonModules.Find("StandardSubsystemsServer") = Undefined Then
		Return Undefined;
	EndIf;
	
	// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
	Return Eval("StandardSubsystemsServer");
EndFunction

// Returns the Common common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleCommon()
	If Metadata.CommonModules.Find("Common") = Undefined Then
		Return Undefined;
	EndIf;
	
	// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
	Return Eval("Common");
EndFunction

// Returns the flag showing that SSL in the current configuration provides functionality.
//
Function SSL_RequiredVersionAvailable(Val Version = Undefined)
	
	CurrentVersion = Undefined;
	ModuleStandardSubsystemsServer = CommonModuleStandardSubsystemsServer();
	If ModuleStandardSubsystemsServer <> Undefined Then
		Try
			CurrentVersion = ModuleStandardSubsystemsServer.LibraryVersion();
		Except
			CurrentVersion = Undefined;
		EndTry;
	EndIf;
	
	If CurrentVersion = Undefined Then
		// The method of determining the version is missing or broken, consider SSL unavailable.
		Return False
	EndIf;
	CurrentVersion = StrReplace(CurrentVersion, ".", Chars.LF);
	
	NeededVersion = StrReplace(?(Version = Undefined, "2.2.2", Version), ".", Chars.LF);
	
	For Index = 1 To StrLineCount(NeededVersion) Do
		
		CurrentVersionPart = StringToNumber(StrGetLine(CurrentVersion, Index));
		RequiredVersionPart  = StringToNumber(StrGetLine(NeededVersion,  Index));
		
		If CurrentVersionPart = Undefined Then
			Return False;
			
		ElsIf CurrentVersionPart > RequiredVersionPart Then
			Return True;
			
		ElsIf CurrentVersionPart < RequiredVersionPart Then
			Return False;
			
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// Returns the flag of object control in SSL.
//
Function SSL_ObjectExportControl(Node, RegistrationObject)
	
	Sending = DataItemSend.Auto;
	ModuleDataExchangeEvents = CommonModuleEventDataExchange();
	If ModuleDataExchangeEvents <> Undefined Then
		ModuleDataExchangeEvents.OnSendDataToRecipient(RegistrationObject, Sending, , Node);
		Return Sending = DataItemSend.Auto;
	EndIf;
	
	// Unknown SSL version
	Return True;
EndFunction

// Checks whether a reference change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSL_RefChangesRegistration(Node, Ref, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Ref.Metadata()));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		// Getting an object from the Ref
		Result.Total = 1;
		RegistrationObject = Ref.GetObject();
		// RegistrationObject value is Undefined if a passed reference is invalid.
		If RegistrationObject = Undefined Or SSL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, Ref);
			Result.Success = 1;
		EndIf;
		RegistrationObject = Undefined;
	EndIf;	
	
	// Adding additional registration objects.
	If Result.Success > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Ref, Node, NoAutoRegistration) Do
			Result.Total = Result.Total + 1;
			If SSL_ObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Success = Result.Success + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a record set change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSL_SetChangesRegistration(Node, FieldStructure, Details, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Details.Metadata));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		Set = Details.Manager.CreateRecordSet();
		For Each KeyValue In FieldStructure Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		
		If SSL_ObjectExportControl(Node, Set) Then
			ExecuteObjectRegistrationCommand(True, Node, Set);
			Result.Success = 1;
		EndIf;
		
	EndIf;
	
	// Adding additional registration objects.
	If Result.Success > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Set, Node, NoAutoRegistration) Do
			Result.Total = Result.Total + 1;
			If SSL_ObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Success = Result.Success + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a constant change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSL_ConstantChangesRegistration(Node, Details, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Details.Metadata));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		RegistrationObject = Details.Manager.CreateValueManager();
		
		If SSL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, RegistrationObject);
			Result.Success = 1;
		EndIf;
		
	EndIf;	
	
	Return Result;
EndFunction

// Checks whether a metadata set can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSL_MetadataChangesRegistration(Node, Details, NoAutoRegistration)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If Details.IsCollection Then
		For Each MetaKind In Details.Metadata Do
			CurDetails = MetadataCharacteristics(MetaKind);
			AddResults(Result, SSL_MetadataChangesRegistration(Node, CurDetails, NoAutoRegistration) );
		EndDo;
	Else;
		AddResults(Result, SSL_MetadataObjectChangesRegistration(Node, Details, NoAutoRegistration) );
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a metadata object can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSL_MetadataObjectChangesRegistration(Node, Details, NoAutoRegistration)
	
	Result = New Structure("Total, Success", 0, 0);
	
	CompositionItem = Node.Metadata().Content.Find(Details.Metadata);
	If CompositionItem = Undefined Then
		// Cannot execute a registration
		Return Result;
	EndIf;
	
	If (Not NoAutoRegistration) AND CompositionItem.AutoRecord <> AutoChangeRecord.Allow Then
		// Auto record is not supported.
		Return Result;
	EndIf;
	
	CurTableName = Details.TableName;
	If Details.IsConstant Then
		AddResults(Result, SSL_ConstantChangesRegistration(Node, Details) );
		Return Result;
		
	ElsIf Details.IsReference Then
		DimensionFields = "Ref";
		
	ElsIf Details.IsSet Then
		DimensionFields = "";
		For Each Row In RecordSetDimensions(CurTableName) Do
			DimensionFields = DimensionFields + "," + Row.Name
		EndDo;
		DimensionFields = Mid(DimensionFields, 2);
		If IsBlankString(DimensionFields) Then
			// There are no dimensions with main filter in the information register.
			// All changes are registered for a metadata object.
			ExchangePlans.RecordChanges(Node, Details.Metadata);
			// To calculate the result.
			Query = New Query("SELECT
			|Count(*) AS Count
			|FROM " + CurTableName + "
			|");
			Selection = Query.Execute().Select();
			Selection.Next();
			Result.Total = Selection.Count;
			Result.Success = Selection.Count;
			Return Result;
		EndIf;
	Else
		Return Result;
	EndIf;
	
	Query = New Query("
		|SELECT DISTINCT 
		| " + DimensionFields + "
		|FROM 
		|	" + CurTableName + "
		|");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Details.IsSet Then
			Data = New Structure(DimensionFields);
			FillPropertyValues(Data, Selection);
			AddResults(Result, SSL_SetChangesRegistration(Node, Data, Details) );
		ElsIf Details.IsReference Then
			AddResults(Result, SSL_RefChangesRegistration(Node, Selection.Ref, NoAutoRegistration) );
		EndIf;
	EndDo;

	Return Result;
EndFunction

// Updating and registering MOID data for the passed node.
//
Function SSL_UpdateAndRegisterMasterNodeMetadataObjectID(Val Node) Export
	
	Result = New Structure("Total, Success", 0 , 0);
	
	MetaNodeExchangePlan = Node.Metadata();
	
	If (Not DIBModeAvailable)                                      // Current SSL version does not support MOID.
		Or (ExchangePlans.MasterNode() <> Undefined)              // Current infobase is a subordinate node.
		Or (Not MetaNodeExchangePlan.DistributedInfoBase) Then // passed node is not a DIB node
		Return Result;
	EndIf;
	
	// Registering everything for DIB without SSL rule control.
	
	// Registering changes for the MetadataObjectIDs catalog
	MetaCatalog = Metadata.Catalogs["MetadataObjectIDs"];
	If MetaNodeExchangePlan.Content.Contains(MetaCatalog) Then
		ExchangePlans.RecordChanges(Node, MetaCatalog);
		
		Query = New Query("SELECT COUNT(Ref) AS ItemCount FROM Catalog.MetadataObjectIDs");
		Result.Success = Query.Execute().Unload()[0].ItemCount;
	EndIf;
	
	// Predefined items
	Result.Success = Result.Success 
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.Catalogs)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCharacteristicTypes)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfAccounts)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCalculationTypes);
	
	Result.Total = Result.Success;
	Result.Insert("Command", True);
	
	Return Result;
EndFunction

Function RegisterPredefinedObjectChangeForNode(Val Node, Val MetadataCollection)
	
	NodeContent = Node.Metadata().Content;
	Result  = 0;
	Query     = New Query;
	
	For Each MetadataObject In MetadataCollection Do
		If NodeContent.Contains(MetadataObject) Then
			
			Query.Text = "
				|SELECT
				|	Ref
				|FROM
				|	" + MetadataObject.FullName() + "
				|WHERE
				|	Predefined";
			Selection = Query.Execute().Select();
			
			Result = Result + Selection.Count();
			
			// Registering for DIB without SSL rule control.
			While Selection.Next() Do
				ExchangePlans.RecordChanges(Node, Selection.Ref);
			EndDo;
			
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndIf
