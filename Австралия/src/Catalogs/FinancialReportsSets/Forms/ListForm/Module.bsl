#Region Variables

&AtClient
Var IdleHandlerParameters;

&AtClient
Var TimeConsumingOperationForm;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	SetListSetsConditionalAppearance();
	
	TimeConsumingOperationFormID = New UUID;
	
	PeriodType = Enums.Periodicity.Year;
	BeginOfPeriod = BegOfYear(CurrentSessionDate());
	EndOfPeriod = EndOfYear(CurrentSessionDate());
	
	CommonClientServer.SetFilterItem(ListReportsTypes.Filter, "ReportsSet", 0, DataCompositionComparisonType.Equal, , True);
	CommonClientServer.SetFilterItem(ListInstances.Filter, "ReportType", 0, DataCompositionComparisonType.Equal, , True);
	
	FileInfobase = Common.FileInfobase();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject,, "ListSets");
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject,, "ListReportsTypes");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
		Items.CompareInstances.Title = NStr("en = 'Compare instances (Thin client)'; ru = 'Сравнить экземпляры (Тонкий клиент)';pl = 'Porównaj przykłady (cienki klient)';es_ES = 'Comparar las instancias (Cliente ligero)';es_CO = 'Comparar las instancias (Cliente ligero)';tr = 'Örnekleri karşılaştır (İnce istemci)';it = 'Confrontare istanze (Thin client)';de = 'Vergleich von Instanzen (Thin Client)'");
		Items.CompareInstances.Enabled = False;
	#EndIf
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportSetStatusOnChange(Item)
	
	CommonClientServer.SetFilterItem(ListSets.Filter, "Status", ReportSetStatus, DataCompositionComparisonType.Equal, , ValueIsFilled(ReportSetStatus));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersListSets

&AtClient
Procedure ListSetsOnActivateRow(Item)
	
	AttachIdleHandler("ListSetsOnActivateRowIdleHandler", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersListReportsTypes

&AtClient
Procedure ListReportsTypesOnActivateRow(Item)
	
	AttachIdleHandler("ListReportsTypesOnActivateRowIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure ListReportsTypesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure("Key", RowSelected);
	FormParameters.Insert("ReportsSet", Items.ListSets.CurrentData.Ref);
	OpenForm("Catalog.FinancialReportsTypes.Form.ItemForm", FormParameters);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersListInstances

&AtClient
Procedure ListInstancesBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	CurrentData = Items.ListReportsTypes.CurrentData;
	If CurrentData <> Undefined Then
		GenerateReports(CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListInstancesOnActivateRow(Item)
	
	#If Not WebClient Then
		Items.CompareInstances.Enabled = Items.ListInstances.SelectedRows.Count() > 1;
	#EndIf
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateSet(Command)
	
	CurrentData = Items.ListSets.CurrentData;
	If CurrentData <> Undefined Then
		GenerateReports(CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure CompareInstances(Command)
	
	#If Not WebClient Then
		ComparedReports = ReportsToBeCompared();
		If ComparedReports <> Undefined Then
			
			SpreadsheetDocuments = New Structure("Left, Right", ComparedReports[0].Result, ComparedReports[1].Result);
			SpreadsheetDocumentsAddress = PutToTempStorage(SpreadsheetDocuments, UUID);
			
			FormParameters = New Structure("SpreadsheetDocumentsAddress, TitleLeft, TitleRight", 
				SpreadsheetDocumentsAddress, ComparedReports[0].Title, ComparedReports[1].Title);
			
			OpenForm("CommonForm.CompareSpreadsheetDocuments", FormParameters, ThisObject, New UUID);
			
		EndIf;
	#EndIf
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.BeginOfValidityPeriod.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EndOfValidityPeriod.Name);
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ListInstances.BeginOfPeriod");
	FilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	
	FilterItem = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ListInstances.EndOfPeriod");
	FilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	Item.Appearance.SetParameterValue("Format", "L=ru; DLF=D");
	
EndProcedure

&AtServer
Procedure SetListSetsConditionalAppearance()
	
	ConditionalAppearanceItems = ListSets.ConditionalAppearance.Items;
	
	Item = ConditionalAppearanceItems.Add();
	Item.Appearance.SetParameterValue("TextColor", WebColors.Magenta);
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Status");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Enums.FinancialReportingSetsStatuses.Inactive;
	
	Item = ConditionalAppearanceItems.Add();
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gainsboro);
	StrikedOutFont = New Font( , , , , , True);
	Item.Appearance.SetParameterValue("Font", StrikedOutFont);
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DeletionMark");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
EndProcedure

&AtServer
Function ReportsToBeCompared()
	
	If Items.ListInstances.SelectedRows.Count() < 2 Then
		Return Undefined;
	EndIf;
	
	ComparedReports = New Array;
	For Index = 0 To 1 Do
		
		Instance = Items.ListInstances.SelectedRows[Index];
		ResultStorage = Common.ObjectAttributeValue(Instance, "ReportResult");
		ReportResult = ResultStorage.Get();
		If ReportResult = Undefined Then
			Return Undefined;
		EndIf;
		
		ReportData = New Structure("Title, Result");
		ReportData.Result = PutToTempStorage(ReportResult, UUID);
		ReportData.Title = String(Instance);
		
		ComparedReports.Add(ReportData);
		
	EndDo;
	
	Return ComparedReports;
	
EndFunction

#Region IdleHandlers

&AtClient
Procedure ListSetsOnActivateRowIdleHandler()
	
	CurrentSet = Items.ListSets.CurrentRow;
	CommonClientServer.SetFilterItem(ListReportsTypes.Filter, "ReportsSet", CurrentSet, DataCompositionComparisonType.Equal, , True);
	
	CurrentReportType = Items.ListReportsTypes.CurrentRow;
	CommonClientServer.SetFilterItem(ListInstances.Filter, "ReportsSet", CurrentSet, DataCompositionComparisonType.Equal, , True);
	CommonClientServer.SetFilterItem(ListInstances.Filter, "ReportType", CurrentReportType, DataCompositionComparisonType.Equal, , True);
	
EndProcedure

&AtClient
Procedure ListReportsTypesOnActivateRowIdleHandler()
	
	CurrentReportType = Items.ListReportsTypes.CurrentRow;
	
	If CurrentReportType = Undefined Then
		
		CurrentReportType = GetFirstFinancialReportsTypes(Items.ListSets.CurrentRow);
		
		ThisObject.CurrentItem = Items.ListReportsTypes;
		Items.ListReportsTypes.CurrentRow = CurrentReportType;
		
	EndIf;
	
	CommonClientServer.SetFilterItem(ListInstances.Filter, "ReportType", CurrentReportType, DataCompositionComparisonType.Equal, , True);
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Function GenerateReports(CurrentData)
	
	InstancesParameters = FinancialReportingClientServer.ReportGenerationNewParameters();
	InstancesParameters.Insert("Resource", "Amount");
	InstancesParameters.OpenForms = TypeOf(CurrentData.Ref) = Type("CatalogRef.FinancialReportsSets");
	FillPropertyValues(InstancesParameters, ThisObject, , "OpenForms");
	FormParameters = New Structure("InstancesParameters", InstancesParameters);
	ReportGenerator = New NotifyDescription("GenerateReportsInstances", ThisObject, CurrentData.Ref);
	OpenForm("Catalog.FinancialReportsSets.Form.ReportParametersForm", FormParameters, ThisObject, , , , ReportGenerator);
	
EndFunction

&AtClient
Procedure GenerateReportsInstances(InstancesParameters, ReportsPack) Export
	
	If InstancesParameters = Undefined
		Or InstancesParameters = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, InstancesParameters);
	JobID = New UUID;
	TimeConsumingOperationForm = TimeConsumingOperationsClient.OpenTimeConsumingOperationForm(ThisObject, JobID);
	
	If Not FileInfobase Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
	PrepareSetsData(ReportsPack);
	
	If FileInfobase Then
		LoadPreparedData();
	EndIf;
	Items.ListInstances.Refresh();
	
EndProcedure

&AtServer
Function PrepareSetsData(ReportsPack)
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	InstancesParameters = PrepareSetsParameters(ReportsPack);
	If FileInfobase Then
		
		StorageAddress = PutToTempStorage(Undefined, UUID);
		FinancialReportingServer.GenerateReportsSet(InstancesParameters, StorageAddress);
		ExecutionResult = New Structure("JobCompleted", True);
		
	Else
		
		ProcedureName = "FinancialReportingServer.GenerateReportsSet";
		ExecutionResult = TimeConsumingOperations.StartBackgroundExecution(
			UUID,
			ProcedureName,
			InstancesParameters,
			"FinancialReportingReportsSetGeneration");
		
		StorageAddress = ExecutionResult.StorageAddress;
		JobID = ExecutionResult.JobID;
		
	EndIf;
	
EndFunction

&AtServer
Function PrepareSetsParameters(ReportsPack)
	
	If TypeOf(ReportsPack) = Type("CatalogRef.FinancialReportsSets") Then
		ReportsTypes = ReportsPack.ReportsTypes.UnloadColumn("FinancialReportType");
	Else
		ReportsTypes = New Array;
		ReportsTypes.Add(ReportsPack);
	EndIf;
	
	CurrentSet = Items.ListSets.CurrentRow;
	InstancesParameters = New Structure;
	InstancesParameters.Insert("MainStorageID", UUID);
	InstancesParameters.Insert("ReportsSet", CurrentSet);
	InstancesParameters.Insert("ReportsTypes", ReportsTypes);
	InstancesParameters.Insert("ReportsPack", ReportsPack);
	
	ReportsInstances = New Map;
	For Each ReportType In ReportsTypes Do
		Address = PutToTempStorage(Undefined, UUID);
		ReportsInstances.Insert(ReportType, Address);
	EndDo;
	InstancesParameters.Insert("ReportsInstances", ReportsInstances);
	
	ReportPeriod = New Structure("BeginOfPeriod, EndOfPeriod, Periodicity");
	ReportPeriod.BeginOfPeriod = BeginOfPeriod;
	ReportPeriod.EndOfPeriod = EndOfPeriod;
	ReportPeriod.Periodicity = New Array;
	InstancesParameters.Insert("ReportPeriod", ReportPeriod);
	
	Filter = New Structure;
	Filter.Insert("Company", Company);
	Filter.Insert("BusinessUnit", BusinessUnit);
	Filter.Insert("LineOfBusiness", LineOfBusiness);
	InstancesParameters.Insert("Filter", Filter);
	
	InstancesParameters.Insert("ReportType", Undefined);
	InstancesParameters.Insert("ReportResult", Undefined);
	InstancesParameters.Insert("Resource", Resource);
	InstancesParameters.Insert("OutputRowCode", False);
	InstancesParameters.Insert("OutputNote", False);
	InstancesParameters.Insert("AmountsInThousands", AmountsInThousands);
	InstancesParameters.Insert("OpenForms", OpenForms);
	
	Return InstancesParameters;
	
EndFunction

&AtClient
Procedure LoadPreparedData()
	
	TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
	ExecutionResult = GetFromTempStorage(StorageAddress);
	If TypeOf(ExecutionResult.ReportsPack) = Type("CatalogRef.FinancialReportsTypes") Or ExecutionResult.OpenForms Then
		
		FormParameters = New Structure("Key");
		
		For Each Instance In ExecutionResult.InstancesData Do
			FormParameters = New Structure("StorageAddress, GenerateReport", Instance.Key, False);
			FormParameters.Insert("UserSettings", Instance.Value);
			OpenForm("Report.FinancialReport.Form.ReportForm", FormParameters, ThisObject, True);
		EndDo;
		
	EndIf;
	
	JobID = Undefined;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			LoadPreparedData();
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("Attachable_CheckJobExecution", IdleHandlerParameters.CurrentInterval, True);
		EndIf;
	Except
		TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure ListSetsOnChange(Item)
	
	Items.ListReportsTypes.Refresh();
	
EndProcedure

#EndRegion

&AtServerNoContext
Function GetFirstFinancialReportsTypes(CurrentFinancialReportsSets)
	
	Result = Undefined;
	
	StringQueryText = 
	"SELECT
	|	CatalogFinancialReportsSets.FinancialReportType AS FinancialReportType
	|FROM
	|	Catalog.FinancialReportsSets.ReportsTypes AS CatalogFinancialReportsSets
	|WHERE
	|	CatalogFinancialReportsSets.Ref = &ReportsSets
	|	AND CatalogFinancialReportsSets.LineNumber = 1";
	
	Query = New Query;
	Query.Text = StringQueryText;
	Query.SetParameter("ReportsSets", CurrentFinancialReportsSets);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Result = SelectionDetailRecords.FinancialReportType;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion