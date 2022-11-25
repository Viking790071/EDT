#Region Variables

&AtClient
Var InterruptIfNotCompleted;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
// Procedure initializes the month end according to IB kind.
//
Procedure InitializeMonthEnd()
	
	Completed = False;
	ExecuteMonthEndAtServer();
	
	If Completed Then
		ActualizeDateBanEditing();
	Else
		
		InterruptIfNotCompleted = False;
		Items["Pages" + String(CurMonth)].CurrentPage = Items["LongOperation" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled	= False;
		Items.CancelMonthEnd.Enabled	= False;
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure manages the actualizing of edit prohibition date in appendix
// 
Procedure ActualizeDateBanEditing()

	If UseProhibitionDatesOfDataImport
		AND Not ValueIsFilled(SetClosingDateOnMonthEndClosing) Then
		
		Response = Undefined;
		OpenForm("DataProcessor.MonthEndClosing.Form.SetClosingDateOnMonthEndClosing",,,,,, New NotifyDescription("ActualizeDateBanEditingEnd", ThisObject));
		
		Return;
		
	ElsIf UseProhibitionDatesOfDataImport
		AND SetClosingDateOnMonthEndClosing = PredefinedValue("Enum.YesNo.Yes") Then
			ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
	EndIf;
	
EndProcedure

&AtClient
Procedure ActualizeDateBanEditingEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If ValueIsFilled(Response) AND Response = DialogReturnCode.Yes Then
        ExecuteChangeProhibitionDatePostpone(EndOfMonth(Date(CurYear, CurMonth, 1)));
    EndIf;
    
EndProcedure

&AtServerNoContext
// Function reads and returns the form attribute value for the specified month
// 
Function AttributeValueFormsOnValueOfMonth(ThisForm, NameOfFlag, CurMonth)
	
	Return ThisForm[NameOfFlag + String(CurMonth)];
	
EndFunction

&AtServer
// Function forms the parameter structure from the form attribute values
//
Function GetStructureParametersAtServer()
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("CurMonth", CurMonth);
	ParametersStructure.Insert("CurYear", CurYear);
	ParametersStructure.Insert("Company", Company);
	
	ExecuteCalculationOfDepreciation = AttributeValueFormsOnValueOfMonth(ThisForm, "AccrueDepreciation", CurMonth);
	ParametersStructure.Insert("ExecuteCalculationOfDepreciation", ExecuteCalculationOfDepreciation);
	
	// Fill the array of operations which are required for month end
	OperationArray = New Array;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "VerifyTaxInvoices", CurMonth) Then		
		OperationArray.Add("VerifyTaxInvoices");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisObject, "VATPayableCalculation", CurMonth) Then
		OperationArray.Add("VATPayableCalculation");
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "DirectCostCalculation", CurMonth) Then		
		OperationArray.Add("DirectCostCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "CostAllocation", CurMonth) Then		
		OperationArray.Add("CostAllocation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ActualCostCalculation", CurMonth) Then		
		OperationArray.Add("ActualCostCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "RetailCostCalculation", CurMonth) Then		
		OperationArray.Add("RetailCostCalculationEarningAccounting");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "ExchangeDifferencesCalculation", CurMonth) Then		
		OperationArray.Add("ExchangeDifferencesCalculation");		
	EndIf;
	
	If AttributeValueFormsOnValueOfMonth(ThisForm, "FinancialResultCalculation", CurMonth) Then		
		OperationArray.Add("FinancialResultCalculation");		
	EndIf;
	
	ParametersStructure.Insert("OperationArray", OperationArray);
	
	Return ParametersStructure;
	
EndFunction

&AtServer
// Procedure executes the month end
//
Procedure ExecuteMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	
	If Common.FileInfobase() Then
		
		DataProcessors.MonthEndClosing.ExecuteMonthEnd(ParametersStructure);
		Completed = True;
		
		GetInfoAboutPeriodsClosing();
		
	Else
		ExecuteClosingMonthInLongOperation(ParametersStructure);
		CheckAndDisplayError(ParametersStructure);
	EndIf;
	
EndProcedure

&AtServer
// Procedure of the month end cancellation.
// It posts month end documents and updates the form state
//
Procedure CancelMonthEndAtServer()
	
	ParametersStructure = GetStructureParametersAtServer();
	DataProcessors.MonthEndClosing.CancelMonthEnd(ParametersStructure);
	GetInfoAboutPeriodsClosing();
	
EndProcedure
// LongActions

&AtServer
// Procedure checks and displays the error
//
Procedure CheckAndDisplayError(ParametersStructure)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	MonthEndErrors.ErrorDescription
	|FROM
	|	InformationRegister.MonthEndErrors AS MonthEndErrors
	|WHERE
	|	MonthEndErrors.Period >= &BeginOfPeriod
	|	AND MonthEndErrors.Period <= &EndOfPeriod";
	
	Query.SetParameter("BeginOfPeriod", BegOfMonth(Date(ParametersStructure.CurYear, ParametersStructure.CurMonth, 1)));
	Query.SetParameter("EndOfPeriod", EndOfMonth(Date(ParametersStructure.CurYear, ParametersStructure.CurMonth, 1)));
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		MessageText = NStr("en = 'Warnings were generated on month-end closing. For more information, see the month-end closing report.'; ru = 'При закрытии месяца были сформированы предупреждения! Подробнее см. в отчете о закрытии месяца.';pl = 'Przy zamknięciu miesiąca zostały wygenerowane ostrzeżenia. Aby uzyskać więcej informacji, zobacz sprawozdanie z zamknięcia miesiąca.';es_ES = 'Avisos se han generado al cerrar el fin de mes. Para más información, ver el informe del cierre del fin de mes.';es_CO = 'Avisos se han generado al cerrar el fin de mes. Para más información, ver el informe del cierre del fin de mes.';tr = 'Ay sonu kapanışında uyarılar oluşturuldu. Daha fazla bilgi için, ay sonu kapanış raporuna bakın.';it = 'Durante la chiusura del mese sono stati generati avvisi! Per ulteriori dettagli, consultare il report sulla chiusura del mese.';de = 'Warnungen wurden am Monatsabschluss generiert. Weitere Informationen finden Sie im Monatsabschlussbericht.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks the state of the month ending
//
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted Then
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled = True;
		Items.CancelMonthEnd.Enabled = True;
		
		ActualizeDateBanEditing();
		
	ElsIf InterruptIfNotCompleted Then
		
		DetachIdleHandler("CheckExecution");
		
		GetInfoAboutPeriodsClosing();
		
		Items["Pages" + String(CurMonth)].CurrentPage = Items["Operations" + String(CurMonth)];
		Items.ExecuteMonthEnd.Enabled	= True;
		Items.CancelMonthEnd.Enabled	= True;
		
		ActualizeDateBanEditing();
		
	Else		
		If BackgroundJobIntervalChecks < 15 Then			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;		
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);		
	EndIf;
	
EndProcedure

&AtServer
// Procedure executes the month end in long actions (in the background)
//
Procedure ExecuteClosingMonthInLongOperation(ParametersStructureBackgroundJob)
	
	ProcedureName = "DataProcessors.MonthEndClosing.ExecuteMonthEnd";
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Month-end closing is in progress'; ru = 'Выполняется закрытие месяца';pl = 'Trwa zamknięcie miesiąca';es_ES = 'Cierre del fin de mes está en progreso';es_CO = 'Cierre del fin de mes está en progreso';tr = 'Ay sonu kapanışı devam ediyor';it = 'La chiusura mensile è in corso';de = 'Monatsabschluss ist in Bearbeitung'");
		
	AssignmentResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName, ParametersStructureBackgroundJob, ExecutionParameters);
	
	Completed = (AssignmentResult.Status = "Completed");
	
	If Completed Then		
		GetInfoAboutPeriodsClosing();		
	Else		
		BackgroundJobID				= AssignmentResult.JobID;
		BackgroundJobStorageAddress	= AssignmentResult.ResultAddress;		
	EndIf;
	
EndProcedure

&AtServer
// Procedure checks the tabular document filling end on server
//
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	
	If TimeConsumingOperations.JobCompleted(BackgroundJobID) Then
		
		Completed					= True;
		CheckResult.JobCompleted	= True;
		CheckResult.Value			= GetFromTempStorage(BackgroundJobStorageAddress);
		
	ElsIf InterruptIfNotCompleted Then		
		TimeConsumingOperations.CancelJobExecution(BackgroundJobID);		
	EndIf;
	
	Return CheckResult;
	
EndFunction

&AtServerNoContext
// Function checks the state of the background job by variable form value
//
Function InProgressBackgroundJob(BackgroundJobID)
	
	If Common.FileInfobase() Then		
		Return False;		
	EndIf;
	
	Task = BackgroundJobs.FindByUUID(BackgroundJobID);
	
	Return (Task <> Undefined) AND (Task.State = BackgroundJobState.Active);
	
EndFunction

&AtClient
// Procedure warns user about action executing impossibility
//
// It is used when closing form, canceling results of closing month
//
Procedure WarnAboutActiveBackgroundJob(Cancel = True)
	
	Cancel = True;
	WarningText = NStr("en = 'Please wait while the process is finished (recommended) or cancel it manually.'; ru = 'Дождитесь окончания рабочего процесса (рекомендуется) либо прервите его самостоятельно.';pl = 'Zaczekaj, aż proces zostanie zakończony (zalecane) lub przerwij go ręcznie.';es_ES = 'Por favor, espere mientras se está finalizando el proceso (recomendado), o cancélelo manualmente.';es_CO = 'Por favor, espere mientras se está finalizando el proceso (recomendado), o cancélelo manualmente.';tr = 'İşlem bittiğinde lütfen bekleyin (önerilir) veya manuel olarak iptal edin.';it = 'Per favore attendete che il processo sia terminato (consigliato) o cancellatelo manualmente.';de = 'Bitte warten Sie, bis der Vorgang abgeschlossen ist (empfohlen) oder brechen Sie ihn manuell ab.'");
	ShowMessageBox(Undefined, WarningText, 10, NStr("en = 'it is impossible to close form.'; ru = 'невозможно закрыть форму.';pl = 'nie można zamknąć formularza.';es_ES = 'es imposible cerrar el formulario.';es_CO = 'es imposible cerrar el formulario.';tr = 'form kapatılamaz.';it = 'E'' impossibile chiudere il modulo.';de = 'Es ist unmöglich, die Form zu schließen.'"));
	
EndProcedure

// End LongActions

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	// GroupNavigationByMonths
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	GroupFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.OrGroup;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Period");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Filled;
	DataFilterItem.Use				= True;
	
	DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Period");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Format", "NG=0");
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupNavigationByMonths");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClient
Function GetStructureNotify()
	
	StructureNotify = New Structure;
	
	StructureNotify.Insert("CurYear", Format(CurYear, "NG=0"));
	StructureNotify.Insert("CurMonth", Format(CurMonth, "ND=2; NLZ=; NG=0"));
	
	Return StructureNotify;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company = Catalogs.Companies.CompanyByDefault();
	
	CurDate		= CurrentSessionDate();
	CurYear		= Year(CurDate);
	CurMonth	= Month(CurDate);
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Company = Constants.ParentCompany.Get();
		Items.Company.Enabled = False;
	EndIf;
	
	SetOperationHandlers();
	SetLabelsText();
	
	// Conditional appearance
	SetConditionalAppearance();
	
	GetInfoAboutPeriodsClosing();
	
	PropertyAccounting				= Constants.UseFixedAssets.Get();
	UseRetail				= Constants.UseRetail.Get();
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	For Ct = 1 To 12 Do
		Items.Find("GroupAccrueDepreciation" + Ct).Visible				= PropertyAccounting;
		Items.Find("GroupRetailCostCalculation" + Ct).Visible			= UseRetail;
		Items.Find("GroupExchangeDifferencesCalculation" + Ct).Visible	= ForeignExchangeAccounting;
	EndDo;
	
	SectionsProperties				= PeriodClosingDatesInternal.SectionsProperties();
	UseProhibitionDatesOfDataImport	= SectionsProperties.ImportRestrictionDatesImplemented;
	SetClosingDateOnMonthEndClosing		= Constants.SetClosingDateOnMonthEndClosing.Get();
	
	DateProhibition = GetEditProhibitionDate();
	
	If ValueIsFilled(DateProhibition) Then
		EditProhibitionDate = DateProhibition;
	Else
		Items.EditProhibitionDate.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - The AtOpen form event handler
//
Procedure OnOpen(Cancel)
	
	SetMarkCurMonth();
	
	SetEnabledMonths();
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted		
			WarnAboutActiveBackgroundJob(Cancel);		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditProhibitionDatesOnClose" Then
		
		ProhibitionDate = GetEditProhibitionDate();
		
		If ValueIsFilled(ProhibitionDate) Then
			EditProhibitionDate = ProhibitionDate;
		Else
			Items.EditProhibitionDate.Visible = False;
		EndIf;
		
	ElsIf EventName = "MonthEndClosingDataProcessorOpenDocumentsNotSelectedCompany" Then
		
		TextMessage = NStr("en = 'Select a company to view a list of Month-end closing documents.'; ru = 'Выберите организацию для просмотра списка документов закрытия месяца.';pl = 'Wybierz firmę aby zobaczyć listę dokumentów zamknięcia miesiąca.';es_ES = 'Seleccione una empresa para ver una lista de los documentos de cierre del mes.';es_CO = 'Seleccione una empresa para ver una lista de los documentos de cierre del mes.';tr = 'Ay sonu kapanışı belgelerinin listesini görmek için iş yeri seçin.';it = 'Selezionare una azienda per visualizzare l''elenco dei documenti di chiusura di fine periodo.';de = 'Wählen Sie eine Firma aus, um die Liste der Monatsabschlussdokumente anzuschauen.'");
		CommonClientServer.MessageToUser(TextMessage);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtServer
Function GetEditProhibitionDate()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ClosingDates.Section AS Section,
	|	ClosingDates.Object AS Object,
	|	ClosingDates.User AS User,
	|	ClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	ClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	ClosingDates.Comment AS Comment
	|FROM
	|	InformationRegister.PeriodClosingDates AS ClosingDates,
	|	Constant.UsePeriodClosingDates AS UsePeriodClosingDates
	|WHERE
	|	ClosingDates.User = &User
	|	AND ClosingDates.Object = &Object
	|	AND UsePeriodClosingDates.Value";
	
	Query.SetParameter("User",  Enums.PeriodClosingDatesPurposeTypes.ForAllUsers);
	Query.SetParameter("Object", ChartsOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef());
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.PeriodEndClosingDate;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtServer
Procedure SetLabelsText()
	
	Items.YearAgo.Title		= "" + Format((CurYear - 1), "NG=0") + " <<";
	Items.NextYear.Title	= ">> " + Format((CurYear + 1), "NG=0");
	Items.NextYear.Enabled	= Not (CurYear + 1 > Year(CurrentSessionDate()));
	
EndProcedure

&AtClient
Procedure SetMarkCurMonth()
	
	Items.Months.CurrentPage		= Items.Find("M" + CurMonth);
	
EndProcedure

&AtServer
Procedure ExecuteChangeProhibitionDatePostpone(Date)
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	
	NewRow = RecordSet.Add();
	NewRow.User				= Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
	NewRow.Object			= ChartsOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef();
	NewRow.ProhibitionDate	= Date;
	NewRow.Comment			= "(Default)";
	
	RecordSet.Write(True);
	
	EditProhibitionDate = Date;
	Items.EditProhibitionDate.Visible = True;
	
	SetClosingDateOnMonthEndClosing = Constants.SetClosingDateOnMonthEndClosing.Get();
	
EndProcedure

&AtServer
Procedure GetInfoAboutPeriodsClosing()
	
	ChangedOperations.Clear();
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Coloring of tabs and operations.
	TableMonths = New ValueTable;
	
	TableMonths.Columns.Add("Year",		New TypeDescription("Number"));
	TableMonths.Columns.Add("Month",	New TypeDescription("Number"));
	TableMonths.Columns.Add("Date",		New TypeDescription("Date"));
	
	For Ct = 1 To 12 Do
		NewRow = TableMonths.Add();
		NewRow.Year		= CurYear;
		NewRow.Month	= Ct;
		NewRow.Date		= Date(Format(NewRow.Year, "NFD=0; NG=") + Format(NewRow.Month, "ND=2; NFD=0; NLZ=; NG=") + "01");
	EndDo;
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	TableMonths.Year AS Year,
	|	TableMonths.Month AS Month,
	|	TableMonths.Date AS Date
	|INTO TempTableMonths
	|FROM
	|	&TableMonths AS TableMonths
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NOT AccountingPolicy.PostVATEntriesBySourceDocuments AS UseTaxInvoices,
	|	AccountingPolicy.Period AS Period
	|INTO TempAccountingPolicy
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Year AS Year,
	|	TableMonths.Month AS Month,
	|	TableMonths.Date AS Date,
	|	TempAccountingPolicy.UseTaxInvoices AS UseTaxInvoices,
	|	TempAccountingPolicy.Period AS Period
	|INTO TableMonthsAndPolicy
	|FROM
	|	TempTableMonths AS TableMonths
	|		LEFT JOIN TempAccountingPolicy AS TempAccountingPolicy
	|		ON TableMonths.Date >= TempAccountingPolicy.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonths.Date AS Date,
	|	MAX(TableMonths.Period) AS MaxPeriod
	|INTO TableMonthsMax
	|FROM
	|	TableMonthsAndPolicy AS TableMonths
	|
	|GROUP BY
	|	TableMonths.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableMonthsAndPolicy.Year AS Year,
	|	TableMonthsAndPolicy.Month AS Month,
	|	TableMonthsAndPolicy.Date AS Date,
	|	TableMonthsAndPolicy.UseTaxInvoices AS UseTaxInvoices,
	|	TableMonthsAndPolicy.Period AS Period
	|INTO TableMonths
	|FROM
	|	TableMonthsMax AS TableMonthsMax
	|		INNER JOIN TableMonthsAndPolicy AS TableMonthsAndPolicy
	|		ON TableMonthsMax.Date = TableMonthsAndPolicy.Date
	|			AND TableMonthsMax.MaxPeriod = TableMonthsAndPolicy.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN COUNT(FixedAssetsDepreciation.Ref) > 0
	|			THEN 1
	|		ELSE 0
	|	END AS AccrueDepreciation,
	|	YEAR(FixedAssetsDepreciation.Date) AS Year,
	|	MONTH(FixedAssetsDepreciation.Date) AS Month
	|INTO NestedSelectDepreciation
	|FROM
	|	Document.FixedAssetsDepreciation AS FixedAssetsDepreciation
	|WHERE
	|	FixedAssetsDepreciation.Posted = TRUE
	|	AND YEAR(FixedAssetsDepreciation.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN FixedAssetsDepreciation.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(FixedAssetsDepreciation.Date),
	|	MONTH(FixedAssetsDepreciation.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	COUNT(MonthEndClosing.Ref) AS CountRef,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.DirectCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS DirectCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.CostAllocation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS CostAllocation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.ActualCostCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ActualCostCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.FinancialResultCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS FinancialResultCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.ExchangeDifferencesCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS ExchangeDifferencesCalculation,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.RetailCostCalculationEarningAccounting, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS RetailCostCalculationEarningAccounting,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.VerifyTaxInvoices, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS VerifyTaxInvoices,
	|	SUM(CASE
	|			WHEN ISNULL(MonthEndClosing.VATPayableCalculation, FALSE)
	|				THEN 1
	|			ELSE 0
	|		END) AS VATPayableCalculation,
	|	YEAR(MonthEndClosing.Date) AS Year,
	|	MONTH(MonthEndClosing.Date) AS Month
	|INTO NestedSelect
	|FROM
	|	Document.MonthEndClosing AS MonthEndClosing
	|WHERE
	|	MonthEndClosing.Posted
	|	AND YEAR(MonthEndClosing.Date) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEndClosing.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|GROUP BY
	|	YEAR(MonthEndClosing.Date),
	|	MONTH(MonthEndClosing.Date)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableMonths.Month AS Month,
	|	TableMonths.Year AS Year,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndIsNecessary,
	|	CASE
	|		WHEN SUM(InventoryTurnover.AmountTurnover) <> 0
	|					AND (ISNULL(NestedSelect.DirectCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.CostAllocation, 0) = 0
	|						OR ISNULL(NestedSelect.ActualCostCalculation, 0) = 0
	|						OR ISNULL(NestedSelect.FinancialResultCalculation, 0) = 0)
	|				OR COUNT(POSSummary.Recorder) > 0
	|					AND ISNULL(NestedSelect.RetailCostCalculationEarningAccounting, 0) = 0
	|				OR COUNT(ExchangeRate.Currency) > 0
	|					AND ISNULL(NestedSelect.ExchangeDifferencesCalculation, 0) = 0
	|				OR COUNT(FixedAssets.FixedAsset) > 0
	|					AND ISNULL(NestedSelectDepreciation.AccrueDepreciation, 0) = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AreNecessaryUnperformedSettlements,
	|	CASE
	|		WHEN COUNT(POSSummary.Recorder) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(ExchangeRate.Currency) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculationIsNecessary,
	|	CASE
	|		WHEN COUNT(FixedAssets.FixedAsset) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciationIsNecessary,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MonthEndWasPerformed,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation = 0
	|				OR NestedSelect.CostAllocation = 0
	|				OR NestedSelect.ActualCostCalculation = 0
	|				OR NestedSelect.FinancialResultCalculation = 0
	|				OR NestedSelect.ExchangeDifferencesCalculation = 0
	|				OR NestedSelect.RetailCostCalculationEarningAccounting = 0
	|				OR NestedSelectDepreciation.AccrueDepreciation = 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsNonProducedCalculations,
	|	CASE
	|		WHEN NestedSelect.DirectCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DirectCostCalculation,
	|	CASE
	|		WHEN NestedSelect.CostAllocation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CostAllocation,
	|	CASE
	|		WHEN NestedSelect.ActualCostCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ActualCostCalculation,
	|	CASE
	|		WHEN NestedSelect.FinancialResultCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FinancialResultCalculation,
	|	CASE
	|		WHEN NestedSelect.ExchangeDifferencesCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.RetailCostCalculationEarningAccounting > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailCostCalculationEarningAccounting,
	|	CASE
	|		WHEN TableMonths.UseTaxInvoices
	|			THEN CASE
	|					WHEN NestedSelect.VerifyTaxInvoices > 0
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		ELSE FALSE
	|	END AS VerifyTaxInvoices,
	|	CASE
	|		WHEN NestedSelect.VATPayableCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS VATPayableCalculation,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS HasErrors,
	|	CASE
	|		WHEN NestedSelectDepreciation.AccrueDepreciation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciation,
	|	TableMonths.UseTaxInvoices AS UseTaxInvoice
	|FROM
	|	TableMonths AS TableMonths
	|		LEFT JOIN AccumulationRegister.Inventory.Turnovers(, , Month, ) AS InventoryTurnover
	|		ON (TableMonths.Month = MONTH(InventoryTurnover.Period))
	|			AND (TableMonths.Year = YEAR(InventoryTurnover.Period))
	|			AND (InventoryTurnover.Company = &Company)
	|		LEFT JOIN InformationRegister.ExchangeRate AS ExchangeRate
	|		ON (TableMonths.Month = MONTH(ExchangeRate.Period))
	|			AND (TableMonths.Year = YEAR(ExchangeRate.Period))
	|			AND (ExchangeRate.Company = &Company)
	|		LEFT JOIN AccumulationRegister.POSSummary AS POSSummary
	|		ON (TableMonths.Month = MONTH(POSSummary.Period))
	|			AND (TableMonths.Year = YEAR(POSSummary.Period))
	|			AND (POSSummary.Active = TRUE)
	|			AND (POSSummary.Company = &Company)
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(, , Month, , ) AS FixedAssets
	|		ON (TableMonths.Month = MONTH(FixedAssets.Period))
	|			AND (TableMonths.Year = YEAR(FixedAssets.Period))
	|			AND (FixedAssets.Company = &Company)
	|		LEFT JOIN NestedSelectDepreciation AS NestedSelectDepreciation
	|		ON TableMonths.Year = NestedSelectDepreciation.Year
	|			AND TableMonths.Month = NestedSelectDepreciation.Month
	|		LEFT JOIN NestedSelect AS NestedSelect
	|		ON TableMonths.Year = NestedSelect.Year
	|			AND TableMonths.Month = NestedSelect.Month
	|		LEFT JOIN InformationRegister.MonthEndErrors AS MonthEndErrors
	|		ON (TableMonths.Year = YEAR(MonthEndErrors.Period))
	|			AND (TableMonths.Month = MONTH(MonthEndErrors.Period))
	|			AND (CASE
	|				WHEN &FilterByCompanyIsNecessary
	|					THEN MonthEndErrors.Recorder.Company = &Company
	|				ELSE TRUE
	|			END)
	|
	|GROUP BY
	|	TableMonths.Month,
	|	TableMonths.Year,
	|	CASE
	|		WHEN MonthEndErrors.ErrorDescription > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN ISNULL(FixedAssets.CostClosingBalance, 0) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN NestedSelectDepreciation.AccrueDepreciation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.DirectCostCalculation,
	|	NestedSelect.CostAllocation,
	|	NestedSelect.ActualCostCalculation,
	|	NestedSelect.FinancialResultCalculation,
	|	NestedSelect.RetailCostCalculationEarningAccounting,
	|	NestedSelectDepreciation.AccrueDepreciation,
	|	NestedSelect.ExchangeDifferencesCalculation,
	|	CASE
	|		WHEN NestedSelect.CountRef > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.VerifyTaxInvoices,
	|	TableMonths.UseTaxInvoices,
	|	CASE
	|		WHEN NestedSelect.VATPayableCalculation > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	NestedSelect.VATPayableCalculation
	|
	|ORDER BY
	|	Year,
	|	Month";
	
	Query.SetParameter("Company",						ParentCompany);
	Query.SetParameter("FilterByCompanyIsNecessary",	Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("TableMonths",					TableMonths);
	Query.SetParameter("Year",							CurYear);
	
	CurrentMonth	= Month(CurrentSessionDate());
	CurrentYear		= Year(CurrentSessionDate());
	Result			= Query.Execute();
	Selection		= Result.Select();
	
	While Selection.Next() Do
		
		Items["M" + Selection.Month].Enabled = True;
		
		// Bookmarks.
		If Selection.Year = CurrentYear
			AND Selection.Month = CurrentMonth
			AND Not Selection.MonthEndWasPerformed
			AND Not Selection.AccrueDepreciation Then
			
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end was not performed.'; ru = 'Закрытие месяца не выполнялось.';pl = 'Zamknięcie miesiąca nie zostało wykonane.';es_ES = 'No se realizó el fin de mes.';es_CO = 'No se realizó el fin de mes.';tr = 'Ay sonu gerçekleşmedi.';it = 'Fine periodo non eseguito.';de = 'Monatsende nicht gemacht.'");
			
		ElsIf (Selection.Month > CurrentMonth AND Selection.Year = CurrentYear)
			OR Selection.Year > CurrentYear Then
			
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
			Items["M" + Selection.Month].Enabled = False;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end was not performed.'; ru = 'Закрытие месяца не выполнялось.';pl = 'Zamknięcie miesiąca nie zostało wykonane.';es_ES = 'No se realizó el fin de mes.';es_CO = 'No se realizó el fin de mes.';tr = 'Ay sonu gerçekleşmedi.';it = 'Fine periodo non eseguito.';de = 'Monatsende nicht gemacht.'");
			
		ElsIf (Selection.MonthEndIsNecessary
				AND Not Selection.MonthEndWasPerformed)
			OR (Selection.RetailCostCalculationIsNecessary
				AND Not Selection.RetailCostCalculationEarningAccounting)
			OR (Selection.ExchangeDifferencesCalculationIsNecessary
				AND Not Selection.ExchangeDifferencesCalculation)
			OR (Selection.AccrueDepreciationIsNecessary
				AND Not Selection.AccrueDepreciation) Then
				
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end is required.'; ru = 'Требуется закрытие месяца.';pl = 'Jest wymagane zamknięcie miesiąca.';es_ES = 'Se requiere el fin de mes.';es_CO = 'Se requiere el fin de mes.';tr = 'Ay sonu gereklidir.';it = 'Richiesto fine periodo.';de = 'Monatsende erforderlich.'");
			
		ElsIf (Selection.MonthEndIsNecessary
				AND Selection.MonthEndWasPerformed
				AND Selection.AreNecessaryUnperformedSettlements)
			OR Selection.HasErrors Then
			
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end is required.'; ru = 'Требуется закрытие месяца.';pl = 'Jest wymagane zamknięcie miesiąca.';es_ES = 'Se requiere el fin de mes.';es_CO = 'Se requiere el fin de mes.';tr = 'Ay sonu gereklidir.';it = 'Richiesto fine periodo.';de = 'Monatsende erforderlich.'");
			
		Else
			Items["M" + Selection.Month].Picture = Items.Green.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end has finished without mistakes.'; ru = 'Закрытие месяца выполнено с ошибками.';pl = 'Zamknięcie miesiąca zakończyło się bez błędów.';es_ES = 'El fin de mes ha terminado sin errores.';es_CO = 'El fin de mes ha terminado sin errores.';tr = 'Ay sonu hatasız tamamlandı.';it = 'Fine periodo terminata senza errori.';de = 'Monatsende ohne Fehler beendet.'");
			
		EndIf;
		
		// Operations.
		ThisForm["CostAllocation" + Selection.Month]					= Selection.CostAllocation;
		ThisForm["ExchangeDifferencesCalculation" + Selection.Month]	= Selection.ExchangeDifferencesCalculation;
		ThisForm["DirectCostCalculation" + Selection.Month]				= Selection.DirectCostCalculation;
		ThisForm["RetailCostCalculation" + Selection.Month]				= Selection.RetailCostCalculationEarningAccounting;
		ThisForm["ActualCostCalculation" + Selection.Month]				= Selection.ActualCostCalculation;
		ThisForm["FinancialResultCalculation" + Selection.Month]		= Selection.FinancialResultCalculation;
		ThisForm["AccrueDepreciation" + Selection.Month]				= Selection.AccrueDepreciation;
		ThisForm["VerifyTaxInvoices" + Selection.Month]					= Selection.VerifyTaxInvoices;
		ThisForm["VATPayableCalculation" + Selection.Month]				= Selection.VATPayableCalculation;
		
		Items.Find("GroupVerifyTaxInvoices" + Selection.Month).Visible = Selection.UseTaxInvoice;
		
		If Selection.MonthEndIsNecessary Then
			
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= ?(ThisForm["CostAllocation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= ?(ThisForm["DirectCostCalculation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= ?(ThisForm["ActualCostCalculation" + Selection.Month], 
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= ?(ThisForm["FinancialResultCalculation" + Selection.Month],
				Items.Green.Picture, Items.Red.Picture);
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.GreenIsNotRequired.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			
		ElsIf Selection.Month > CurrentMonth
			OR Selection.Year > CurrentYear Then
			  
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= Items.Gray.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= Items.Gray.Picture;
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.Gray.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.Gray.Picture;
			
		Else
			
			Items.Find("CostAllocationPicture" + Selection.Month).Picture				= Items.GreenIsNotRequired.Picture;
			Items.Find("DirectCostCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			Items.Find("ActualCostCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			Items.Find("FinancialResultCalculationPicture" + Selection.Month).Picture	= Items.GreenIsNotRequired.Picture;
			Items.Find("VerifyTaxInvoicesPicture" + Selection.Month).Picture			= Items.GreenIsNotRequired.Picture;
			Items.Find("VATPayableCalculationPicture" + Selection.Month).Picture		= Items.GreenIsNotRequired.Picture;
			
		EndIf;
		
		If Selection.ExchangeDifferencesCalculationIsNecessary Then
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("ExchangeDifferencesCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["ExchangeDifferencesCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.RetailCostCalculationIsNecessary Then
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("RetailCostCalculationPicture" + Selection.Month).Picture = 
				?(ThisForm["RetailCostCalculation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		If Selection.AccrueDepreciationIsNecessary Then
			Items.Find("AccrueDepreciationPicture" + Selection.Month).Picture = 
				?(ThisForm["AccrueDepreciation" + Selection.Month], Items.Green.Picture, Items.Red.Picture);
		Else
			Items.Find("AccrueDepreciationPicture" + Selection.Month).Picture = 
				?(ThisForm["AccrueDepreciation" + Selection.Month], Items.Green.Picture, Items.GreenIsNotRequired.Picture);
		EndIf;
		
		ThisForm["TextErrorCostAllocation" + Selection.Month]					= "";
		ThisForm["TextErrorDirectCostCalculation" + Selection.Month]			= "";
		ThisForm["TextErrorActualCostCalculation" + Selection.Month]			= "";
		ThisForm["TextErrorFinancialResultCalculation" + Selection.Month]		= "";
		ThisForm["TextErrorExchangeDifferencesCalculation" + Selection.Month]	= "";
		ThisForm["TextErrorCalculationPrimecostInRetail" + Selection.Month]		= "";
		ThisForm["TextErrorAccrueDepreciation" + Selection.Month]				= "";
		ThisForm["TextErrorVerifyTaxInvoices" + Selection.Month]				= "";
		ThisForm["TextErrorVATPayableCalculation" + Selection.Month]			= "";

	EndDo;
	
	// Errors.
	Query = New Query;
	
	Query.Text = 
	"SELECT ALLOWED
	|	MONTH(MonthEndErrors.Period) AS Month,
	|	MonthEndErrors.OperationKind,
	|	MonthEndErrors.ErrorDescription
	|FROM
	|	InformationRegister.MonthEndErrors AS MonthEndErrors
	|WHERE
	|	MonthEndErrors.Active
	|	AND YEAR(MonthEndErrors.Period) = &Year
	|	AND CASE
	|			WHEN &FilterByCompanyIsNecessary
	|				THEN MonthEndErrors.Recorder.Company = &Company
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	Month";
	
	Query.SetParameter("FilterByCompanyIsNecessary",	Not Constants.AccountingBySubsidiaryCompany.Get());
	Query.SetParameter("Company",						ParentCompany);
	Query.SetParameter("Year",							CurYear);
	
	SelectionErrors = Query.Execute().Select();
	
	While SelectionErrors.Next() Do
		
		If TrimAll(SelectionErrors.OperationKind) = "CostAllocation" Then
			Items.Find("CostAllocationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCostAllocation" + SelectionErrors.Month] = 
					NStr("en = 'While cost allocation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При распределении затрат возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas alokacji kosztów wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante la asignación de costes, han ocurrido errores.
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la asignación de costes, han ocurrido errores.
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Maliyet dağıtımı sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante l''allocazione dei costi.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Während der Kostenzuordnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ExchangeDifferencesCalculation" Then
			Items.Find("ExchangeDifferencesCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While currency difference calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При расчете курсовых разниц возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas obliczania różnic kursowych wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante el cálculo de la diferencia de monedas, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el cálculo de la diferencia de monedas, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Para birimi fark hesaplaması sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante il calcolo delle differenze di cambio.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Bei der Währungsdifferenzberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "DirectCostCalculation" Then
			Items.Find("DirectCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While direct cost calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При расчете прямых затрат возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas obliczania kosztów bezpośrednich wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante el cálculo de costes directos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el cálculo de costes directos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Direkt maliyet hesaplaması sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante il calcolo delle differenze di cambio.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Während der direkten Kostenberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "RetailCostCalculation" Then
			Items.Find("RetailCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month] = 
					NStr("en = 'While calculation of primecost in retail the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При расчете розничной себестоимости возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas obliczania kosztów własnych w handlu detalicznym wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante el cálculo del costo de producción en la venta al por menos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el cálculo del costo de producción en la venta al por menos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'İlk maliyet hesaplaması sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante il calcolo del costo della merce per la vendita al dettaglio.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Bei der Berechnung der Grundkosten im Einzelhandel sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ActualCostCalculation" Then
			Items.Find("ActualCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorActualCostCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While actual primecost calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При расчете себестоимости возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas faktycznego obliczania kosztów pierwotnych wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante el cálculo del costo de producción actual, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el cálculo del costo de producción actual, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Para birimi fark hesaplaması sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante il calcolo del costo della merce.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Während der eigentlichen Grundkostenberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "FinancialResultCalculation" Then
			Items.Find("FinancialResultCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month] = 
					NStr("en = 'An error has occurred during closing of temporary accounts. 
					     |For more details see month-end closing report'; 
					     |ru = 'При расчете финансового результата произошла ошибка. 
					     |Дополнительные сведения приведены в отчете по закрытию месяца';
					     |pl = 'Podczas zamknięcia tymczasowych kont zaistniał błąd. 
					     |Więcej szczegółów można zobaczyć w raporcie zamknięcie miesiąca';
					     |es_ES = 'Se ha producido un error durante el cierre de las cuentas temporales.
					     | Para más detalles ver el informe de cierre del mes';
					     |es_CO = 'Se ha producido un error durante el cierre de las cuentas temporales.
					     | Para más detalles ver el informe de cierre del mes';
					     |tr = 'Geçici hesapların kapatılması sırasında bir hata oluştu. 
					     |Daha fazla ayrıntı için ay sonu kapanış raporuna bakın';
					     |it = 'Un errore si è registrato durante la chiusura dei conti temporanei.
					     |Per maggiori dettagli guardare report di chiusura fine mese';
					     |de = 'Ein Fahler ist beim Abschließen von temporären Konten aufgetreten.
					     |Für weitere Informationen sehen Sie den Monatsabschluss an'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "AccrueDepreciation" Then
			Items.Find("AccrueDepreciationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month] = 
					NStr("en = 'While depreciation charging the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При начислении амортизации возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas naliczania amortyzacji wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante la carga de la depreciación, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la carga de la depreciación, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Maliyet tahsisi sırasında hatalar meydana geldi. 
					     |Ay sonu raporundaki ayrıntıları görün.';
					     |it = 'Si sono verificati errori durante il caricamento dell''ammortamento.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Während der Abschreibung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "Verify tax invoices" Then
			Items.Find("VerifyTaxInvoicesPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month] = 
					NStr("en = 'While verifing tax invoice the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При проверке наличия налоговых инвойсов возникли ошибки.
					     |Смотрите отчет по закрытию месяца.';
					     |pl = 'Podczas weryfikacji faktury VAT wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante la verificación de la factura de impuestos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la verificación de la factura fiscal, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Vergi faturası doğrulanırken hatalar oluştu.
					     |Ayrıntılar için ay sonu raporuna bakabilirsiniz.';
					     |it = 'Si sono registrati errori durante il controllo della fattura fiscale.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Bei der Überprüfung der Steuerrechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "VAT payable calculation" Then
			Items.Find("VATPayableCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While VAT payable calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = 'При расчете НДС к оплате возникли ошибки.
					     |Смотрите отчет по закрытию месяца';
					     |pl = 'Podczas naliczania podatku VAT wystąpiły błędy. 
					     |Zobacz szczegóły w raporcie z końca miesiąca.';
					     |es_ES = 'Durante el cálculo del IVA a pagar, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el cálculo del IVA a pagar, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Ödenecek KDV hesaplanırken hatalar oluştu.
					     |Ayrıntılar için ay sonu raporuna bakabilirsiniz.';
					     |it = 'Durante il calcolo della IVA da pagare si sono registrati errori.
					     |Guardare i dettagli nel report di fine periodo.';
					     |de = 'Bei der Berechnung der USt. sind die Fehler aufgetreten.
					     |Details finden Sie im Monatsabschlussbericht.'");
			EndIf;
		EndIf;
		
	EndDo;
	
	For Ct = 1 To 12 Do
			
		If Not ValueIsFilled(ThisForm["TextErrorCostAllocation" + Ct]) Then
			If Items.Find("CostAllocationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'; ru = 'Расчет себестоимости в рознице (суммовой учет) выполнен успешно!';pl = 'KWS dla terminalów POS z metodą inwentaryzacji detalicznej został pomyślnie obliczony.';es_ES = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista se ha calculado con éxito.';es_CO = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista se ha calculado con éxito.';tr = 'Envanter perakende yöntemli POS için SMM başarıyla hesaplandı.';it = 'Il costo del venduto per Punto Vendita con metodo al dettaglio è stato calcolato con successo.';de = 'Wareneinsatz für POS mit Inventurmethode (Einzelhandel) wurde erfolgreich berechnet.'");						
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'; ru = 'Расчет себестоимости в рознице (суммовой учет) не требуется.';pl = 'Obliczenie KWS dla punktów sprzedaży z metodą inwentaryzacji detalicznej nie jest wymagane.';es_ES = 'No se requiere el cálculo del coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';es_CO = 'No se requiere el cálculo del coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';tr = 'Envanter perakende yöntemli POS için SMM hesaplaması gerekli değil.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non è richiesto.';de = 'Eine Wareneinsatz-Berechnung für POS mit Inventurmethode (Einzelhandel) ist nicht erforderlich.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Costs are not allocated.'; ru = 'Распределение затрат не производилось.';pl = 'Koszty nie są przydzielane.';es_ES = 'Costes no se han asignado.';es_CO = 'Costes no se han asignado.';tr = 'Maliyetler dağıtılmadı.';it = 'I costi non sono allocati.';de = 'Kosten sind nicht zugeordnet.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Red.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Cost allocation is required.'; ru = 'Требуется выполнить распределение затрат.';pl = 'Wymagana jest alokacja kosztów.';es_ES = 'Se requiere una asignación de costes.';es_CO = 'Se requiere una asignación de costes.';tr = 'Maliyet dağıtımı gerekli.';it = 'È richiesta l''allocazione dei costi.';de = 'Kostenzuordnung ist erforderlich.'");			
			EndIf;			
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + Ct]) Then
			If Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs are calculated.'; ru = 'Расчет прямых затрат выполнен успешно!';pl = 'Koszty bezpośrednie są obliczone.';es_ES = 'Costes directos se han calculado.';es_CO = 'Costes directos se han calculado.';tr = 'Direkt giderler hesaplandı.';it = 'I costi diretti sono stati calcolati.';de = 'Direkte Kosten werden berechnet.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is not required.'; ru = 'Расчет прямых затрат не требуется.';pl = 'Obliczanie kosztów bezpośrednich nie jest wymagane.';es_ES = 'No se requiere el cálculo de costes directos.';es_CO = 'No se requiere el cálculo de costes directos.';tr = 'Doğrudan maliyet hesaplanması gerekmiyor.';it = 'Il calcolo dei costi diretti non è necessaria.';de = 'Eine direkte Kostenberechnung ist nicht erforderlich.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs were not calculated.'; ru = 'Расчет прямых затрат не производился.';pl = 'Koszty bezpośrednie nie zostały obliczone.';es_ES = 'Costes directos no se han calculado.';es_CO = 'Costes directos no se han calculado.';tr = 'Direkt giderler hesaplanmadı.';it = 'I costi diretti non sono stati calcolati.';de = 'Direkte Kosten wurden nicht berechnet.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is required.'; ru = 'Требуется выполнить расчет прямых затрат.';pl = 'Wymagane jest bezpośrednie obliczenie kosztów.';es_ES = 'No se requiere el cálculo de costes directos.';es_CO = 'No se requiere el cálculo de costes directos.';tr = 'Doğrudan maliyet hesabı gerekiyor.';it = 'E'' richiesto il calcolo dei costi diretti.';de = 'Direkte Kostenberechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + Ct]) Then
			If Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost is calculated successfully.'; ru = 'Расчет фактической себестоимости выполнен успешно!';pl = 'Obliczenie faktycznego kosztu wykonano pomyślnie.';es_ES = 'Coste actual se ha calculado con éxito.';es_CO = 'Coste actual se ha calculado con éxito.';tr = 'Gerçekleşen maliyet başarıyla hesaplandı.';it = 'Il costo effettivo è stato calcolato con successo.';de = 'Selbstkosten werden erfolgreich berechnet.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is not required.'; ru = 'Расчет фактической себестоимости не требуется.';pl = 'Obliczenie faktycznego kosztu nie jest wymagany.';es_ES = 'No se requiere el cálculo del coste actual.';es_CO = 'No se requiere el cálculo del coste actual.';tr = 'Gerçekleşen maliyet hesaplaması zorunlu değil.';it = 'Il calcolo del costo effettivo non è necessario.';de = ' Selbstkostenberechnung ist nicht erforderlich.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation was not performed.'; ru = 'Расчет фактической себестоимости не производился.';pl = 'Obliczenie faktycznego kosztu nie zostało wykonane.';es_ES = 'Cálculo del coste actual no se ha realizado.';es_CO = 'Cálculo del coste actual no se ha realizado.';tr = 'Gerçekleşen maliyet hesaplaması yapılmadı.';it = 'Il calcolo del costo effettivo non è stato eseguito.';de = 'Selbstkostenberechnung wurde nicht durchgeführt.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is required.'; ru = 'Требуется выполнить расчет фактической себестоимости.';pl = 'Wymagane jest obliczanie kosztów bezpośrednich.';es_ES = 'Se requiere el cálculo del coste actual.';es_CO = 'Se requiere el cálculo del coste actual.';tr = 'Gerçekleşen maliyet hesaplaması gerekiyor.';it = 'E'' richiesto il calcolo del costo effettivo.';de = 'Die Selbstkostenberechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + Ct]) Then
			If Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result is calculated.'; ru = 'Расчет финансового результата выполнен успешно!';pl = 'Wynik finansowy został obliczony pomyślnie.';es_ES = 'Resultado financiero se ha calculado.';es_CO = 'Resultado financiero se ha calculado.';tr = 'Finansal sonuç hesaplanıyor.';it = 'Risultato finanziario calcolato.';de = 'Das finanzielle Ergebnis wird berechnet.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Temporary accounts closing is not required.'; ru = 'Расчёт финансового результата не требуется.';pl = 'Zamknięcie tymczasowych kont nie jest wymagane.';es_ES = 'No se requiere el cierre temporal de las cuentas.';es_CO = 'No se requiere el cierre temporal de las cuentas.';tr = 'Geçici hesapların kapatılması gerekli değildir.';it = 'La chiusura dei conti temporanei non è richiesta';de = 'Abschließen von temporären Konten nicht erforderlich.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Accounts were not closed.'; ru = 'Счета не были закрыты.';pl = 'Konta nie zostały zamknięte.';es_ES = 'Las cuentas no se han cerrado.';es_CO = 'Las cuentas no se han cerrado.';tr = 'Hesaplar kapatılmadı.';it = 'I conti  non sono stati chiusi.';de = 'Konten wurden nicht geschlossen.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Temporary accounts closing is required.'; ru = 'Требуется расчёт финансового результата.';pl = 'Zamknięcie tymczasowych kont jest wymagane.';es_ES = 'Se requiere el cierre temporal de las cuentas.';es_CO = 'Se requiere el cierre temporal de las cuentas.';tr = 'Geçici hesapların kapatılması gerekiyor.';it = 'La chiusura dei conti temporanei è richiesta.';de = 'Abschließen von temporären Konten ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + Ct]) Then
			If Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are successfully calculated.'; ru = 'Расчет курсовых разниц выполнен успешно!';pl = 'Różnice kursowe zostały obliczone pomyślnie.';es_ES = 'Diferencias de tipos de cambios se han calculado con éxito.';es_CO = 'Diferencias de tipos de cambios se han calculado con éxito.';tr = 'Döviz kuru farklılıkları başarıyla hesaplandı.';it = 'Le differenze di cambio sono state calcolate con successo.';de = 'Wechselkursdifferenzen werden erfolgreich berechnet.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not required.'; ru = 'Расчет курсовых разниц не требуется.';pl = 'Nie jest wymagane obliczenie różnic kursowych.';es_ES = 'No se requieren las diferencias de tipos de cambio.';es_CO = 'No se requieren las diferencias de tipos de cambio.';tr = 'Döviz kuru farklılıkları gerekmiyor.';it = 'Le differenze di cambio non sono richieste.';de = 'Wechselkursdifferenzen sind nicht erforderlich.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not calculated.'; ru = 'Расчет курсовых разниц не производился.';pl = 'Różnice kursowe nie są obliczane.';es_ES = 'Diferencias de tipos de cambio no se han calculado.';es_CO = 'Diferencias de tipos de cambio no se han calculado.';tr = 'Döviz kuru farklılıkları hesaplanmadı.';it = 'Le differenze di cambio non sono state calcolate.';de = 'Wechselkursdifferenzen werden nicht berechnet.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are required.'; ru = 'Требуется выполнить расчет курсовых разниц.';pl = 'Wymagane jest obliczenie różnic kursowych.';es_ES = 'Se requieren las diferencias de tipos de cambio.';es_CO = 'Se requieren las diferencias de tipos de cambio.';tr = 'Döviz kuru farklılıkları gerekiyor.';it = 'Sono richieste le differenze dei tassi di cambio.';de = 'Wechselkursdifferenzen sind erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + Ct]) Then
			If Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'; ru = 'Расчет себестоимости в рознице (суммовой учет) выполнен успешно!';pl = 'KWS dla terminalów POS z metodą inwentaryzacji detalicznej został pomyślnie obliczony.';es_ES = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista se ha calculado con éxito.';es_CO = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista se ha calculado con éxito.';tr = 'Envanter perakende yöntemli POS için SMM başarıyla hesaplandı.';it = 'Il costo del venduto per Punto Vendita con metodo al dettaglio è stato calcolato con successo.';de = 'Wareneinsatz für POS mit Inventurmethode (Einzelhandel) wurde erfolgreich berechnet.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'; ru = 'Расчет себестоимости в рознице (суммовой учет) не требуется.';pl = 'Obliczenie KWS dla punktów sprzedaży z metodą inwentaryzacji detalicznej nie jest wymagane.';es_ES = 'No se requiere el cálculo del coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';es_CO = 'No se requiere el cálculo del coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';tr = 'Envanter perakende yöntemli POS için SMM hesaplaması gerekli değil.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non è richiesto.';de = 'Eine Wareneinsatz-Berechnung für POS mit Inventurmethode (Einzelhandel) ist nicht erforderlich.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is not calculated.'; ru = 'Расчет себестоимости в рознице (суммовой учет) не производился.';pl = 'KWS dla punktów sprzedaży z metodą inwentaryzacji detalicznej nie jest obliczony.';es_ES = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista no se ha calculado.';es_CO = 'Coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista no se ha calculado.';tr = 'Envanter perakende yöntemli POS için SMM hesaplanmadı.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non è stato calcolato.';de = 'Wareneinsatz für POS mit Inventurmethode (Einzelhandel) werden nicht berechnet.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is required.'; ru = 'Требуется выполнить расчет себестоимости в рознице (суммовой учет).';pl = 'Obliczenie KWS dla punktów sprzedaży terminalów POS z metodą inwentaryzacji detalicznej jest wymagane.';es_ES = 'Se requiere el coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';es_CO = 'Se requiere el coste de mercancías vendidas para el TPV con el método de inventario de la venta minorista.';tr = 'Envanter perakende yöntemli POS için SMM hesaplaması gerekli.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio è richiesto.';de = 'Eine Wareneinsatz-Berechnung für POS mit Inventurmethode (Einzelhandel) ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + Ct]) Then
			If Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is accrued.'; ru = 'Начисление амортизации выполнено успешно!';pl = 'Amortyzacja została naliczona pomyślnie.';es_ES = 'Depreciación se ha acumulado.';es_CO = 'Depreciación se ha acumulado.';tr = 'Amortisman tahakkuk etti.';it = 'L''ammortamento è maturato.';de = 'Abschreibungen sind angefallen.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not required.'; ru = 'Начисление амортизации не требуется.';pl = 'Amortyzacja nie wymagana.';es_ES = 'No se requiere la depreciación.';es_CO = 'No se requiere la depreciación.';tr = 'Amortisman gerekmiyor.';it = 'L''ammortamento non è necessario.';de = 'Abschreibung ist nicht erforderlich.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not accrued.'; ru = 'Начисление амортизации не производилось.';pl = 'Amortyzacja nie była wykonana.';es_ES = 'Depreciación no se ha acumulado.';es_CO = 'Depreciación no se ha acumulado.';tr = 'Amortisman tahakkuk etmedi.';it = 'L''ammortamento non è maturato.';de = 'Abschreibung ist nicht angefallen.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is required.'; ru = 'Требуется выполнить начисление амортизации.';pl = 'Amortyzacja wymagana.';es_ES = 'Se requiere la depreciación.';es_CO = 'Se requiere la depreciación.';tr = 'Amortisman gerekiyor.';it = 'E'' richiesto l''ammortamento.';de = 'Abschreibung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + Ct]) Then
			If Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoices are verified.'; ru = 'Проверка налоговых инвойсов выполнена.';pl = 'Faktury VAT są zweryfikowane.';es_ES = 'Facturas de impuestos se han verificado.';es_CO = 'Facturas fiscales se han verificado.';tr = 'Vergi faturaları doğrulandı.';it = 'Le fatture fiscali sono verificate.';de = 'Steuerrechnungen werden verifiziert.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not required.'; ru = 'Проверка налоговых инвойсов не требуется.';pl = 'Weryfikacja faktury VAT nie jest wymagana.';es_ES = 'No se requiere la verificación de facturas de impuestos.';es_CO = 'No se requiere la verificación de facturas fiscales.';tr = 'Vergi faturası doğrulaması gerekmiyor.';it = 'Il controllo della fattura fiscale non è necessario.';de = 'Die Überprüfung der Steuerrechnung ist nicht erforderlich.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not accrued.'; ru = 'Проверка налоговых инвойсов не производилась.';pl = 'Weryfikacja faktury VAT nie była wykonana.';es_ES = 'Verificación de facturas de impuestos no se ha acumulado.';es_CO = 'Verificación de facturas fiscales no se ha acumulado.';tr = 'Vergi faturasının doğrulanması tahakkuk etmedi.';it = 'Il controllo della fattura fiscale non è stato maturato.';de = 'Steuerrechnungsprüfung ist nicht angefallen.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is required.'; ru = 'Требуется выполнить проверку налоговых инвойсов.';pl = 'Weryfikacja faktury VAT jest wymagana.';es_ES = 'Se requiere la verificación de facturas de impuestos.';es_CO = 'Se requiere la verificación de facturas fiscales.';tr = 'Vergi faturası doğrulaması gerekiyor.';it = 'Il controllo della Fattura Fiscale è richiesto.';de = 'Die Überprüfung der Steuerrechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + Ct]) Then
			If Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable is calculated.'; ru = 'НДС к оплате рассчитан.';pl = 'VAT należny jest obliczany.';es_ES = 'El IVA a pagar se ha calculado.';es_CO = 'El IVA a pagar se ha calculado.';tr = 'Ödenecek KDV hesaplandı.';it = 'IVA da pagare è stata calcolata.';de = 'Die zu zahlende USt. wird berechnet.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is not required.'; ru = 'Расчет НДС к оплате не требуется.';pl = 'Obliczenie VAT należnego nie jest wymagane.';es_ES = 'No se requiere el cálculo del IVA a pagar.';es_CO = 'No se requiere el cálculo del IVA a pagar.';tr = 'Ödenecek KDV hesaplaması gerekmiyor.';it = 'Il calcolo dell''IVA da pagare non è richiesto.';de = 'Eine Berechnung der zu zahlenden USt. ist nicht erforderlich.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable was not calculated.'; ru = 'НДС к оплате не был рассчитан.';pl = 'VAT należny nie został obliczony.';es_ES = 'El IVA a pagar no se ha calculado.';es_CO = 'El IVA a pagar no se ha calculado.';tr = 'Ödenecek KDV hesaplanmadı.';it = 'L''IVA da pagare non è stato calcolato.';de = 'Die zu zahlende USt. wurde nicht berechnet.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is required.'; ru = 'Требуется расчет НДС к оплате.';pl = 'Obliczenie VAT należnego jest wymagane.';es_ES = 'Se requiere el cálculo del IVA a pagar.';es_CO = 'Se requiere el cálculo del IVA a pagar.';tr = 'Ödenecek KDV hesaplaması gerekli.';it = 'Il calcolo dell''IVA da pagare è richiesto.';de = 'Eine Berechnung der zu zahlenden USt. ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Items.Find("CostAllocationPicture" + Ct).Picture							= Items.GreenIsNotRequired.Picture
			AND Items.Find("DirectCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("ActualCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("FinancialResultCalculationPicture" + Ct).Picture		= Items.GreenIsNotRequired.Picture
			AND Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture	= Items.GreenIsNotRequired.Picture
			AND Items.Find("RetailCostCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("AccrueDepreciationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture
			AND Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture					= Items.GreenIsNotRequired.Picture
			AND Items.Find("VATPayableCalculationPicture" + Ct).Picture				= Items.GreenIsNotRequired.Picture Then
			
			Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = 
				NStr("en = 'Month-end closing is not required as there is no data for calculation.'; ru = 'Закрытие месяца не требуется, т.к. нет данных для расчета.';pl = 'Zamknięcie miesiąca nie jest wymagane, ponieważ nie ma danych do obliczenia.';es_ES = 'Cierre del fin de mes no se requiere, porque no hay datos para el cálculo.';es_CO = 'Cierre del fin de mes no se requiere, porque no hay datos para el cálculo.';tr = 'Hesaplanacak veri olmadığından ay sonu kapanışı gerekmiyor.';it = 'La chiusura mensile non è necessaria in quanto non vi sono dati per il calcolo.';de = 'Monatsabschluss ist nicht erforderlich, da keine Daten zur Berechnung vorhanden sind.'");
			
		Else
			
			If Items["M" + Ct].Picture = Items.Green.Picture Then
				Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = 
					NStr("en = 'The month-end closing is completed.
					|To view the list of month-end closing documents for this company and this year, click ""Documents""'; 
					|ru = 'Закрытие месяца завершено.
					|Для просмотра списка документов закрытия месяца для этой организации за этот год нажмите ""Документы""';
					|pl = 'Zamknięcie miesiąca jest zakończone.
					|Aby zobaczyć listę dokumentów o zamknięciu miesiąca dla tej firmy i tego roku, kliknij ""Dokumenty""';
					|es_ES = 'El cierre de fin de mes se ha completado.
					|Para ver la lista de los documentos de cierre del mes de esta empresa y de este año, hacer clic en ""Documentos"".';
					|es_CO = 'El cierre de fin de mes se ha completado.
					|Para ver la lista de los documentos de cierre del mes de esta empresa y de este año, hacer clic en ""Documentos"".';
					|tr = 'Ay sonu kapanışı tamamlandı.
					|Bu iş yerinin ve bu yılın ay sonu kapanışı belge listesini görüntülemek için ''''Belgeler'''' butonuna tıklayın.';
					|it = 'La chiusura di fine periodo è completata.
					| Per visualizzare l''elenco dei documenti di chiusura di fine periodo per questa azienda e quest''anno, cliccare su ""Documenti""';
					|de = 'Der Monatsabschluss ist abgeschlossen.
					|Um die Liste der Monatsabschlussdokumente für diese Firma und dieses Jahr anzuschauen, klicken Sie auf ""Dokumente""'");
			Else 
				Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = "";
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AccrueDepreciationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorAccrueDepreciation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure DirectCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorDirectCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure CostAllocationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorCostAllocation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ActualCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorActualCostCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure RetailCostCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorCalculationPrimecostInRetail" + CurMonth]);
	
EndProcedure

&AtClient
Procedure ExchangeDifferencesCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorExchangeDifferencesCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure FinancialResultCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorFinancialResultCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure VerifyTaxInvoicesPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorVerifyTaxInvoices" + CurMonth]);
	
EndProcedure

&AtClient
Procedure VATPayableCalculationPictureClick(Item)
	
	ShowMessageBox(Undefined, ThisForm["TextErrorVATPayableCalculation" + CurMonth]);
	
EndProcedure

&AtClient
Procedure MonthsOnCurrentPageChange(Item, CurrentPage)
	
	If Not Completed 
		And ValueIsFilled(BackgroundJobID) Then
		Return;
	EndIf;
	
	If ChangedOperations.Count() Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewMonthPage", CurrentPage.Name);
		
		Items.Months.CurrentPage = Items["M" + CurMonth];
		
		Notification = New NotifyDescription("MonthSettingsChangedQueryBoxHandler", ThisObject, AdditionalParameters);
		
		TextQuery = NStr("en = 'You have changed the settings for this ""Month-end closing"" document. To apply these changes and repost the document, click ""Continue"". To cancel the changes, click ""Cancel"".'; ru = 'Вы изменили настройки для этого документа ""Закрытие месяца"". Чтобы применить изменения и провести документ заново, нажмите ""Продолжить"". Чтобы отменить изменения, нажмите ""Отмена"".';pl = 'Ustawienia dla tego dokumentu ""Zamknięcie miesiąca"" zostały zmienione. Aby zastosować te zmiany i ponownie zatwierdzić dokument, kliknij ""Kontynuuj"". Aby anulować zmiany, kliknij ""Anuluj"".';es_ES = 'Ha cambiado la configuración de este documento de ""Cierre del mes"". Para aplicar estos cambios y volver a publicar el documento, haga clic en ""Continuar"". Para cancelar los cambios, haga clic en ""Cancelar"".';es_CO = 'Ha cambiado la configuración de este documento de ""Cierre del mes"". Para aplicar estos cambios y volver a publicar el documento, haga clic en ""Continuar"". Para cancelar los cambios, haga clic en ""Cancelar"".';tr = 'Bu ""Ay sonu kapanışı"" belgesinin ayarlarını değiştirdiniz. Değişikliklerin uygulanması ve belgenin yeniden kaydedilmesi için ""Devam""a tıklayın. Değişiklikleri iptal etmek için ""İptal""e tıklayın.';it = 'Sono state modificate le impostazioni per questo documento ""Chiusura mensile"". Per applicare queste modifiche e ripubblicare il documento, cliccare su ""Continuare"". Per annullare le modifiche, cliccare su ""Annullare"".';de = 'Sie haben die Einstellungen für dieses Dokument ""Monatsabschluss"" geändert. Um diese Änderungen zu verwenden und das Dokument neu zu buchen, klicken Sie auf ""Weiter"". Um diese Änderungen zu verwerfen, klicken Sie auf ""Abbrechen"".'"); 
		
		Mode = New ValueList;
		Mode.Add(DialogReturnCode.OK, NStr("en = 'Continue'; ru = 'Продолжить';pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continuare';de = 'Weiter'"));
		Mode.Add(DialogReturnCode.Cancel);
		
		ShowQueryBox(Notification, TextQuery, Mode);
		
	Else
		
		ProcessMonthsPageChange();
		
	EndIf;
	
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	SetEnabledMonths();
	
	Notify("MonthEndClosingDataProcessorChangeCompany", New Structure("Company", Company));
	
EndProcedure

&AtClient
Procedure EditProhibitionDateClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
// Procedure is the ExecuteMonthEnd command handler
//
Procedure ExecuteMonthEnd(Command)
	
	ProcessExecuteMonthEndCommand();
	
EndProcedure

&AtClient
Procedure NextYear(Command)
	
	CurYear = CurYear + 1;
	SetLabelsText();
	GetInfoAboutPeriodsClosing();
	
	StructureNotify = GetStructureNotify();
	
	Notify("MonthEndClosingDataProcessorOnChangePeriod", StructureNotify);
	
EndProcedure

&AtClient
Procedure YearAgo(Command)
	
	CurYear = ?(CurYear = 1, CurYear, CurYear - 1);
	SetLabelsText();
	GetInfoAboutPeriodsClosing();
	
	StructureNotify = GetStructureNotify();
	
	Notify("MonthEndClosingDataProcessorOnChangePeriod", StructureNotify);
	
EndProcedure

&AtClient
Procedure CancelMonthEnd(Command)
	
	If BackgroundJobID <> New UUID
		AND Not Completed
		AND InProgressBackgroundJob(BackgroundJobID) Then // Check for the case if the job has been interrupted		
			WarnAboutActiveBackgroundJob();		
	Else		
		CancelMonthEndAtServer();	
	EndIf;
	
	Notify("MonthEndClosingDataProcessorRefreshList");
	
EndProcedure

&AtClient
Procedure GenerateReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("BeginOfPeriod", BegOfMonth(Date(CurYear, CurMonth, 1)));
	FormParameters.Insert("EndOfPeriod", EndOfMonth(Date(CurYear, CurMonth, 1)));
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("GeneratingDate", CommonClient.SessionDate());

	OpenForm("Report.MonthEndReport.ObjectForm", FormParameters);
	
EndProcedure

// LongActions

&AtClient
// Procedure-handler of the command "Abort month closing in long Operations"
//
Procedure AbortClosingMonthInLongOperation(Command)
	
	InterruptIfNotCompleted = True;
	CheckExecution();
	
EndProcedure

// End LongActions

&AtClient
Procedure CheckAll(Command)
	
	ProcessCheckUncheckAll(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	ProcessCheckUncheckAll(False);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ProcessCheckUncheckAll(Flag)
	
	OperationsList = OperationsList();
	
	For Each Operation In OperationsList Do
		
		ItemName = Operation + CurMonth;
		
		If Items[ItemName].Parent.Visible And ThisObject[ItemName] <> Flag Then
			
			ThisObject[ItemName] = Flag;
			RegisterChangedOperation(ItemName);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ProcessExecuteMonthEndCommand()
	
	If EndOfMonth(Date(CurYear, CurMonth, 1)) <= EndOfDay(EditProhibitionDate) Then
		ShowMessageBox(Undefined,
			NStr("en = 'Cannot close the month. It is included in the accounting period that is already closed.'; ru = 'Не удалось закрыть месяц. Он включен в уже закрытый учетный период.';pl = 'Nie zamknąć miesiąca. Jest on włączony do już zamkniętego okresu rozliczeniowego.';es_ES = 'No se puede cerrar el mes. Se incluye en el período contable que ya está cerrado.';es_CO = 'No se puede cerrar el mes. Se incluye en el período contable que ya está cerrado.';tr = 'Ay kapatılamıyor. Zaten kapatılmış olan bir hesap dönemine dahil.';it = 'Impossibile chiudere il mese. È incluso nel periodo contabile già chiuso.';de = 'Fehler beim Monatsabschluss. Der bereits abgeschlossene Buchhaltungszeitraum enthält ihn.'"));
		Return;
	EndIf;
	
	InitializeMonthEnd();
	
	Notify("MonthEndClosingDataProcessorRefreshList");
	
EndProcedure

&AtClient
Procedure MonthSettingsChangedQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		ProcessExecuteMonthEndCommand();
		
		If Completed Then
			Items.Months.CurrentPage = Items[AdditionalParameters.NewMonthPage];
			ProcessMonthsPageChange();
		EndIf;
		
	Else
		
		For Each ChangedOperation In ChangedOperations Do
			ThisObject[ChangedOperation.Value] = Not ThisObject[ChangedOperation.Value];
		EndDo;
		ChangedOperations.Clear();
		
		Items.Months.CurrentPage = Items[AdditionalParameters.NewMonthPage];
		ProcessMonthsPageChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessMonthsPageChange()
	
	If Items.Months.CurrentPage = Items.M1 Then
		CurMonth = 1;
	ElsIf Items.Months.CurrentPage = Items.M2 Then
		CurMonth = 2;
	ElsIf Items.Months.CurrentPage = Items.M3 Then
		CurMonth = 3;
	ElsIf Items.Months.CurrentPage = Items.M4 Then
		CurMonth = 4;
	ElsIf Items.Months.CurrentPage = Items.M5 Then
		CurMonth = 5;
	ElsIf Items.Months.CurrentPage = Items.M6 Then
		CurMonth = 6;
	ElsIf Items.Months.CurrentPage = Items.M7 Then
		CurMonth = 7;
	ElsIf Items.Months.CurrentPage = Items.M8 Then
		CurMonth = 8;
	ElsIf Items.Months.CurrentPage = Items.M9 Then
		CurMonth = 9;
	ElsIf Items.Months.CurrentPage = Items.M10 Then
		CurMonth = 10;
	ElsIf Items.Months.CurrentPage = Items.M11 Then
		CurMonth = 11;
	ElsIf Items.Months.CurrentPage = Items.M12 Then
		CurMonth = 12;
	EndIf;
	
	StructureNotify = GetStructureNotify();
	Notify("MonthEndClosingDataProcessorOnChangePeriod", StructureNotify);
	
EndProcedure

&AtServer
Procedure SetOperationHandlers()
	
	OperationsList = OperationsList();
	
	For CounterMonth = 1 To 12 Do
		
		For i = 0 To OperationsList.Count() - 1 Do
			
			Items[OperationsList.Get(i) + CounterMonth].SetAction("OnChange", "Attachable_ItemOperationOnChange");
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function OperationsList()
	
	OperationsList = New Array;
	OperationsList.Add("VerifyTaxInvoices");
	OperationsList.Add("VATPayableCalculation");
	OperationsList.Add("AccrueDepreciation");
	OperationsList.Add("DirectCostCalculation");
	OperationsList.Add("CostAllocation");
	OperationsList.Add("ActualCostCalculation");
	OperationsList.Add("RetailCostCalculation");
	OperationsList.Add("ExchangeDifferencesCalculation");
	OperationsList.Add("FinancialResultCalculation");
	
	Return OperationsList;
	
EndFunction

&AtClient
Procedure RegisterChangedOperation(ItemName)
	
	ChangedOperation = ChangedOperations.FindByValue(ItemName);
	If ChangedOperation = Undefined Then
		ChangedOperations.Add(ItemName);
	Else
		ChangedOperations.Delete(ChangedOperation);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ItemOperationOnChange(Item)
	
	RegisterChangedOperation(Item.Name);
	
EndProcedure

&AtClient
Procedure SetEnabledMonths()
	
	If ValueIsFilled(Company) Then
		Items.Months.Enabled = True;
		GetInfoAboutPeriodsClosing();
	Else
		Items.Months.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion