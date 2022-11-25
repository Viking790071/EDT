#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	ResultTable = RegisteredObjects();
	
	StandardProcessing = False;
	DCSettings = SettingsComposer.GetSettings();
	ExternalDataSets = New Structure("ResultTable", ResultTable);
	
	DCTemplateComposer = New DataCompositionTemplateComposer;
	DCTemplate = DCTemplateComposer.Execute(DataCompositionSchema, DCSettings, DetailsData);
	
	DCProcessor = New DataCompositionProcessor;
	DCProcessor.Initialize(DCTemplate, ExternalDataSets, DetailsData);
	
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	DCResultOutputProcessor.SetDocument(ResultDocument);
	DCResultOutputProcessor.Output(DCProcessor);
	
	ResultDocument.ShowRowGroupLevel(2);
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ResultTable.Count() = 0);
	
EndProcedure

#EndRegion

#Region Private

Function RegisteredObjects()
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	InfobaseUpdate.Ref AS Ref
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate";
	Result = Query.Execute().Unload();
	NodesArray = Result.UnloadColumn("Ref");
	NodesList = New ValueList;
	NodesList.LoadValues(NodesArray);
	
	ResultTable = New ValueTable;
	ResultTable.Columns.Add("ConfigurationSynonym");
	ResultTable.Columns.Add("FullName");
	ResultTable.Columns.Add("ObjectType");
	ResultTable.Columns.Add("Presentation");
	ResultTable.Columns.Add("MetadataType");
	ResultTable.Columns.Add("ObjectCount");
	ResultTable.Columns.Add("PositionInQueue");
	ResultTable.Columns.Add("UpdateHandler");
	ResultTable.Columns.Add("TotalObjectCount", New TypeDescription("Number"));
	
	ExchangePlanComposition = Metadata.ExchangePlans.InfobaseUpdate.Content;
	PresentationMap = New Map;
	
	ConfigurationSynonym = Metadata.Synonym;
	QueryText = "";
	Query       = New Query;
	Query.SetParameter("NodesList", NodesList);
	Restriction  = 0;
	For Each ExchangePlanItem In ExchangePlanComposition Do
		MetadataObject = ExchangePlanItem.Metadata;
		If Not AccessRight("Read", MetadataObject) Then
			Continue;
		EndIf;
		Presentation    = MetadataObject.Presentation();
		FullName        = MetadataObject.FullName();
		FullNameParts = StrSplit(FullName, ".");
		
		// Transforming from "CalculationRegister._DemoBasicAccruals.Recalculation.BasicAccrualsRecalculation.Changes"
		// to "CalculationRegister._DemoBasicAccruals.BasicAccrualsRecalculation.Changes"
		If FullNameParts[0] = "CalculationRegister" AND FullNameParts.Count() = 4 AND FullNameParts[2] = "Recalculation" Then
			FullNameParts.Delete(2); // delete the extra Recalculation
			FullName = StrConcat(FullNameParts, ".");
		EndIf;	
		QueryText = QueryText + ?(QueryText = "", "", "UNION ALL") + "
			|SELECT
			|	""" + MetadataTypePresentation(FullNameParts[0]) + """ AS MetadataType,
			|	""" + FullNameParts[1] + """ AS ObjectType,
			|	""" + FullName + """ AS FullName,
			|	Node.PositionInQueue AS PositionInQueue,
			|	COUNT(*) AS ObjectCount
			|FROM
			|	" + FullName + ".Changes
			|WHERE
			|	Node IN (&NodesList)
			|GROUP BY
			|	Node
			|";
			
		Restriction = Restriction + 1;
		PresentationMap.Insert(FullNameParts[1], Presentation);
		If Restriction = 200 Then
			Query.Text = QueryText;
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				Row = ResultTable.Add();
				FillPropertyValues(Row, Selection);
				Row.ConfigurationSynonym = ConfigurationSynonym;
				Row.Presentation = PresentationMap[Row.ObjectType];
			EndDo;
			Restriction  = 0;
			QueryText = "";
			PresentationMap = New Map;
		EndIf;
		
	EndDo;
	
	If QueryText <> "" Then
		Query.Text = QueryText;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Row = ResultTable.Add();
			FillPropertyValues(Row, Selection);
			Row.ConfigurationSynonym = ConfigurationSynonym;
			Row.Presentation = PresentationMap[Row.ObjectType];
		EndDo;
	EndIf;
	
	HandlersData = UpdateHandlers();
	For Each HandlerData In HandlersData Do
		HandlerName = HandlerData.Key;
		For Each ObjectData In HandlerData.Value Do
			FullObjectName = ObjectData.Key;
			PositionInQueue    = ObjectData.Value.PositionInQueue;
			Count = ObjectData.Value.Count;
			
			FilterParameters = New Structure;
			FilterParameters.Insert("FullName", FullObjectName);
			FilterParameters.Insert("PositionInQueue", PositionInQueue);
			Rows = ResultTable.FindRows(FilterParameters);
			For Each Row In Rows Do
				If Not ValueIsFilled(Row.UpdateHandler) Then
					Row.UpdateHandler = HandlerName;
				Else
					Row.UpdateHandler = Row.UpdateHandler + "," + Chars.LF + HandlerName;
				EndIf;
				Row.TotalObjectCount = Row.TotalObjectCount + Count;
			EndDo;
			
			// Object is fully processed.
			If Rows.Count() = 0 Then
				Row = ResultTable.Add();
				FullNameParts = StrSplit(FullObjectName, ".");
				
				Row.ConfigurationSynonym = ConfigurationSynonym;
				Row.FullName     = FullObjectName;
				Row.ObjectType    = FullNameParts[1];
				Row.Presentation = Metadata.FindByFullName(FullObjectName).Presentation();
				Row.MetadataType = MetadataTypePresentation(FullNameParts[0]);
				Row.PositionInQueue       = PositionInQueue;
				Row.UpdateHandler = HandlerName;
				Row.TotalObjectCount = Row.TotalObjectCount + Count;
				Row.ObjectCount = 0;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return ResultTable;
	
EndFunction

Function MetadataTypePresentation(MetadataType)
	
	Map = New Map;
	Map.Insert("Constant", NStr("ru = 'Константы'; en = 'Constants'; pl = 'Stałe';es_ES = 'Constantes';es_CO = 'Constantes';tr = 'Sabitler';it = 'Costanti';de = 'Konstanten'"));
	Map.Insert("Catalog", NStr("ru = 'Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'"));
	Map.Insert("Document", NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'"));
	Map.Insert("ChartOfCharacteristicTypes", NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'"));
	Map.Insert("ChartOfAccounts", NStr("ru = 'Планы счетов'; en = 'Charts of accounts'; pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planları';it = 'Piani dei conti';de = 'Kontenpläne'"));
	Map.Insert("ChartOfCalculationTypes", NStr("ru = 'Планы видов расчета'; en = 'Charts of calculation types'; pl = 'Plany typów obliczeń';es_ES = 'Diagramas de los tipos de cálculos';es_CO = 'Diagramas de los tipos de cálculos';tr = 'Hesaplama türleri çizelgeleri';it = 'Grafici di tipi di calcolo';de = 'Diagramme der Berechnungstypen'"));
	Map.Insert("InformationRegister", NStr("ru = 'Регистры сведений'; en = 'Information registers'; pl = 'Rejestry informacji';es_ES = 'Registros de información';es_CO = 'Registros de información';tr = 'Bilgi kayıtları';it = 'Registri informazioni';de = 'Informationen registriert'"));
	Map.Insert("AccumulationRegister", NStr("ru = 'Регистры накопления'; en = 'Accumulation registers'; pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulación';es_CO = 'Registros de acumulación';tr = 'Birikim kayıtları';it = 'Registri di accumulo';de = 'Akkumulationsregister'"));
	Map.Insert("AccountingRegister", NStr("ru = 'Регистры бухгалтерии'; en = 'Accounting registers'; pl = 'Rejestry księgowe';es_ES = 'Registros de contabilidad';es_CO = 'Registros de contabilidad';tr = 'Muhasebe kayıtları';it = 'Registri contabili';de = 'Buchhaltungsregister'"));
	Map.Insert("CalculationRegister", NStr("ru = 'Регистры расчета'; en = 'Calculation registers'; pl = 'Rejestry obliczeń';es_ES = 'Registros de cálculos';es_CO = 'Registros de cálculos';tr = 'Hesaplama kayıtları';it = 'Registri di calcolo';de = 'Berechnungsregister'"));
	Map.Insert("BusinessProcess", NStr("ru = 'Бизнес-процессы'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'İş süreçleri';it = 'Processi di business';de = 'Geschäftsprozesse'"));
	Map.Insert("Task", NStr("ru = 'Задач'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'Görevler';it = 'Compiti';de = 'Aufgaben'"));
	
	Return Map[MetadataType];
	
EndFunction

Function UpdateHandlers()
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	DataToProcess = UpdateInfo.DataToProcess;
	
	Return DataToProcess;
	
EndFunction

#EndRegion

#EndIf

