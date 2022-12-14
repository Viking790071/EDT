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
		MessageText = NStr("en = 'Warnings were generated on month-end closing. For more information, see the month-end closing report.'; ru = '?????? ???????????????? ???????????? ???????? ???????????????????????? ????????????????????????????! ?????????????????? ????. ?? ???????????? ?? ???????????????? ????????????.';pl = 'Przy zamkni??ciu miesi??ca zosta??y wygenerowane ostrze??enia. Aby uzyska?? wi??cej informacji, zobacz sprawozdanie z zamkni??cia miesi??ca.';es_ES = 'Avisos se han generado al cerrar el fin de mes. Para m??s informaci??n, ver el informe del cierre del fin de mes.';es_CO = 'Avisos se han generado al cerrar el fin de mes. Para m??s informaci??n, ver el informe del cierre del fin de mes.';tr = 'Ay sonu kapan??????nda uyar??lar olu??turuldu. Daha fazla bilgi i??in, ay sonu kapan???? raporuna bak??n.';it = 'Durante la chiusura del mese sono stati generati avvisi! Per ulteriori dettagli, consultare il report sulla chiusura del mese.';de = 'Warnungen wurden am Monatsabschluss generiert. Weitere Informationen finden Sie im Monatsabschlussbericht.'");
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
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Month-end closing is in progress'; ru = '?????????????????????? ???????????????? ????????????';pl = 'Trwa zamkni??cie miesi??ca';es_ES = 'Cierre del fin de mes est?? en progreso';es_CO = 'Cierre del fin de mes est?? en progreso';tr = 'Ay sonu kapan?????? devam ediyor';it = 'La chiusura mensile ?? in corso';de = 'Monatsabschluss ist in Bearbeitung'");
		
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
	WarningText = NStr("en = 'Please wait while the process is finished (recommended) or cancel it manually.'; ru = '?????????????????? ?????????????????? ???????????????? ???????????????? (??????????????????????????) ???????? ???????????????? ?????? ????????????????????????????.';pl = 'Zaczekaj, a?? proces zostanie zako??czony (zalecane) lub przerwij go r??cznie.';es_ES = 'Por favor, espere mientras se est?? finalizando el proceso (recomendado), o canc??lelo manualmente.';es_CO = 'Por favor, espere mientras se est?? finalizando el proceso (recomendado), o canc??lelo manualmente.';tr = '????lem bitti??inde l??tfen bekleyin (??nerilir) veya manuel olarak iptal edin.';it = 'Per favore attendete che il processo sia terminato (consigliato) o cancellatelo manualmente.';de = 'Bitte warten Sie, bis der Vorgang abgeschlossen ist (empfohlen) oder brechen Sie ihn manuell ab.'");
	ShowMessageBox(Undefined, WarningText, 10, NStr("en = 'it is impossible to close form.'; ru = '???????????????????? ?????????????? ??????????.';pl = 'nie mo??na zamkn???? formularza.';es_ES = 'es imposible cerrar el formulario.';es_CO = 'es imposible cerrar el formulario.';tr = 'form kapat??lamaz.';it = 'E'' impossibile chiudere il modulo.';de = 'Es ist unm??glich, die Form zu schlie??en.'"));
	
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
		
		TextMessage = NStr("en = 'Select a company to view a list of Month-end closing documents.'; ru = '???????????????? ?????????????????????? ?????? ?????????????????? ???????????? ???????????????????? ???????????????? ????????????.';pl = 'Wybierz firm?? aby zobaczy?? list?? dokument??w zamkni??cia miesi??ca.';es_ES = 'Seleccione una empresa para ver una lista de los documentos de cierre del mes.';es_CO = 'Seleccione una empresa para ver una lista de los documentos de cierre del mes.';tr = 'Ay sonu kapan?????? belgelerinin listesini g??rmek i??in i?? yeri se??in.';it = 'Selezionare una azienda per visualizzare l''elenco dei documenti di chiusura di fine periodo.';de = 'W??hlen Sie eine Firma aus, um die Liste der Monatsabschlussdokumente anzuschauen.'");
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
				NStr("en = 'Month-end was not performed.'; ru = '???????????????? ???????????? ???? ??????????????????????.';pl = 'Zamkni??cie miesi??ca nie zosta??o wykonane.';es_ES = 'No se realiz?? el fin de mes.';es_CO = 'No se realiz?? el fin de mes.';tr = 'Ay sonu ger??ekle??medi.';it = 'Fine periodo non eseguito.';de = 'Monatsende nicht gemacht.'");
			
		ElsIf (Selection.Month > CurrentMonth AND Selection.Year = CurrentYear)
			OR Selection.Year > CurrentYear Then
			
			Items["M" + Selection.Month].Picture = Items.Gray.Picture;
			Items["M" + Selection.Month].Enabled = False;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end was not performed.'; ru = '???????????????? ???????????? ???? ??????????????????????.';pl = 'Zamkni??cie miesi??ca nie zosta??o wykonane.';es_ES = 'No se realiz?? el fin de mes.';es_CO = 'No se realiz?? el fin de mes.';tr = 'Ay sonu ger??ekle??medi.';it = 'Fine periodo non eseguito.';de = 'Monatsende nicht gemacht.'");
			
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
				NStr("en = 'Month-end is required.'; ru = '?????????????????? ???????????????? ????????????.';pl = 'Jest wymagane zamkni??cie miesi??ca.';es_ES = 'Se requiere el fin de mes.';es_CO = 'Se requiere el fin de mes.';tr = 'Ay sonu gereklidir.';it = 'Richiesto fine periodo.';de = 'Monatsende erforderlich.'");
			
		ElsIf (Selection.MonthEndIsNecessary
				AND Selection.MonthEndWasPerformed
				AND Selection.AreNecessaryUnperformedSettlements)
			OR Selection.HasErrors Then
			
			Items["M" + Selection.Month].Picture = Items.Yellow.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end is required.'; ru = '?????????????????? ???????????????? ????????????.';pl = 'Jest wymagane zamkni??cie miesi??ca.';es_ES = 'Se requiere el fin de mes.';es_CO = 'Se requiere el fin de mes.';tr = 'Ay sonu gereklidir.';it = 'Richiesto fine periodo.';de = 'Monatsende erforderlich.'");
			
		Else
			Items["M" + Selection.Month].Picture = Items.Green.Picture;
			Items.Find("DecorationPerformClosingNotNeeded" + Selection.Month).Title = 
				NStr("en = 'Month-end has finished without mistakes.'; ru = '???????????????? ???????????? ?????????????????? ?? ????????????????.';pl = 'Zamkni??cie miesi??ca zako??czy??o si?? bez b????d??w.';es_ES = 'El fin de mes ha terminado sin errores.';es_CO = 'El fin de mes ha terminado sin errores.';tr = 'Ay sonu hatas??z tamamland??.';it = 'Fine periodo terminata senza errori.';de = 'Monatsende ohne Fehler beendet.'");
			
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
					     |ru = '?????? ?????????????????????????? ???????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas alokacji koszt??w wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante la asignaci??n de costes, han ocurrido errores.
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la asignaci??n de costes, han ocurrido errores.
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Maliyet da????t??m?? s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
					     |it = 'Si sono verificati errori durante l''allocazione dei costi.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'W??hrend der Kostenzuordnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "ExchangeDifferencesCalculation" Then
			Items.Find("ExchangeDifferencesCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While currency difference calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ?????????????? ???????????????? ???????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas obliczania r????nic kursowych wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante el c??lculo de la diferencia de monedas, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el c??lculo de la diferencia de monedas, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Para birimi fark hesaplamas?? s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
					     |it = 'Si sono verificati errori durante il calcolo delle differenze di cambio.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Bei der W??hrungsdifferenzberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "DirectCostCalculation" Then
			Items.Find("DirectCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorDirectCostCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While direct cost calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ?????????????? ???????????? ???????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas obliczania koszt??w bezpo??rednich wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante el c??lculo de costes directos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el c??lculo de costes directos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Direkt maliyet hesaplamas?? s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
					     |it = 'Si sono verificati errori durante il calcolo delle differenze di cambio.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'W??hrend der direkten Kostenberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "RetailCostCalculation" Then
			Items.Find("RetailCostCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month]) Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + SelectionErrors.Month] = 
					NStr("en = 'While calculation of primecost in retail the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ?????????????? ?????????????????? ?????????????????????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas obliczania koszt??w w??asnych w handlu detalicznym wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante el c??lculo del costo de producci??n en la venta al por menos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el c??lculo del costo de producci??n en la venta al por menos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = '??lk maliyet hesaplamas?? s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
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
					     |ru = '?????? ?????????????? ?????????????????????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas faktycznego obliczania koszt??w pierwotnych wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante el c??lculo del costo de producci??n actual, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el c??lculo del costo de producci??n actual, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Para birimi fark hesaplamas?? s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
					     |it = 'Si sono verificati errori durante il calcolo del costo della merce.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'W??hrend der eigentlichen Grundkostenberechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "FinancialResultCalculation" Then
			Items.Find("FinancialResultCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorFinancialResultCalculation" + SelectionErrors.Month] = 
					NStr("en = 'An error has occurred during closing of temporary accounts. 
					     |For more details see month-end closing report'; 
					     |ru = '?????? ?????????????? ?????????????????????? ???????????????????? ?????????????????? ????????????. 
					     |???????????????????????????? ???????????????? ?????????????????? ?? ???????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas zamkni??cia tymczasowych kont zaistnia?? b????d. 
					     |Wi??cej szczeg??????w mo??na zobaczy?? w raporcie zamkni??cie miesi??ca';
					     |es_ES = 'Se ha producido un error durante el cierre de las cuentas temporales.
					     | Para m??s detalles ver el informe de cierre del mes';
					     |es_CO = 'Se ha producido un error durante el cierre de las cuentas temporales.
					     | Para m??s detalles ver el informe de cierre del mes';
					     |tr = 'Ge??ici hesaplar??n kapat??lmas?? s??ras??nda bir hata olu??tu. 
					     |Daha fazla ayr??nt?? i??in ay sonu kapan???? raporuna bak??n';
					     |it = 'Un errore si ?? registrato durante la chiusura dei conti temporanei.
					     |Per maggiori dettagli guardare report di chiusura fine mese';
					     |de = 'Ein Fahler ist beim Abschlie??en von tempor??ren Konten aufgetreten.
					     |F??r weitere Informationen sehen Sie den Monatsabschluss an'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "AccrueDepreciation" Then
			Items.Find("AccrueDepreciationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorAccrueDepreciation" + SelectionErrors.Month] = 
					NStr("en = 'While depreciation charging the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ???????????????????? ?????????????????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas naliczania amortyzacji wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante la carga de la depreciaci??n, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la carga de la depreciaci??n, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Maliyet tahsisi s??ras??nda hatalar meydana geldi. 
					     |Ay sonu raporundaki ayr??nt??lar?? g??r??n.';
					     |it = 'Si sono verificati errori durante il caricamento dell''ammortamento.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'W??hrend der Abschreibung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "Verify tax invoices" Then
			Items.Find("VerifyTaxInvoicesPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVerifyTaxInvoices" + SelectionErrors.Month] = 
					NStr("en = 'While verifing tax invoice the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ???????????????? ?????????????? ?????????????????? ???????????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????.';
					     |pl = 'Podczas weryfikacji faktury VAT wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante la verificaci??n de la factura de impuestos, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante la verificaci??n de la factura fiscal, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = 'Vergi faturas?? do??rulan??rken hatalar olu??tu.
					     |Ayr??nt??lar i??in ay sonu raporuna bakabilirsiniz.';
					     |it = 'Si sono registrati errori durante il controllo della fattura fiscale.
					     |Guardate i dettagli nel report di fine mese.';
					     |de = 'Bei der ??berpr??fung der Steuerrechnung sind die Fehler aufgetreten.
					     |Siehe Details im Monatsendbericht.'");
			EndIf;
		ElsIf TrimAll(SelectionErrors.OperationKind) = "VAT payable calculation" Then
			Items.Find("VATPayableCalculationPicture" + SelectionErrors.Month).Picture = Items.Yellow.Picture;
			
			If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month]) Then
				ThisForm["TextErrorVATPayableCalculation" + SelectionErrors.Month] = 
					NStr("en = 'While VAT payable calculation the errors have occurred. 
					     |See details in the month end report.'; 
					     |ru = '?????? ?????????????? ?????? ?? ???????????? ???????????????? ????????????.
					     |???????????????? ?????????? ???? ???????????????? ????????????';
					     |pl = 'Podczas naliczania podatku VAT wyst??pi??y b????dy. 
					     |Zobacz szczeg????y w raporcie z ko??ca miesi??ca.';
					     |es_ES = 'Durante el c??lculo del IVA a pagar, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |es_CO = 'Durante el c??lculo del IVA a pagar, han ocurrido errores. 
					     |Ver detalles en el informe del fin de mes.';
					     |tr = '??denecek KDV hesaplan??rken hatalar olu??tu.
					     |Ayr??nt??lar i??in ay sonu raporuna bakabilirsiniz.';
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
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'; ru = '???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????) ???????????????? ??????????????!';pl = 'KWS dla terminal??w POS z metod?? inwentaryzacji detalicznej zosta?? pomy??lnie obliczony.';es_ES = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista se ha calculado con ??xito.';es_CO = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista se ha calculado con ??xito.';tr = 'Envanter perakende y??ntemli POS i??in SMM ba??ar??yla hesapland??.';it = 'Il costo del venduto per Punto Vendita con metodo al dettaglio ?? stato calcolato con successo.';de = 'Wareneinsatz f??r POS mit Inventurmethode (Einzelhandel) wurde erfolgreich berechnet.'");						
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'; ru = '???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????) ???? ??????????????????.';pl = 'Obliczenie KWS dla punkt??w sprzeda??y z metod?? inwentaryzacji detalicznej nie jest wymagane.';es_ES = 'No se requiere el c??lculo del coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';es_CO = 'No se requiere el c??lculo del coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';tr = 'Envanter perakende y??ntemli POS i??in SMM hesaplamas?? gerekli de??il.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non ?? richiesto.';de = 'Eine Wareneinsatz-Berechnung f??r POS mit Inventurmethode (Einzelhandel) ist nicht erforderlich.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Costs are not allocated.'; ru = '?????????????????????????? ???????????? ???? ??????????????????????????.';pl = 'Koszty nie s?? przydzielane.';es_ES = 'Costes no se han asignado.';es_CO = 'Costes no se han asignado.';tr = 'Maliyetler da????t??lmad??.';it = 'I costi non sono allocati.';de = 'Kosten sind nicht zugeordnet.'");				
			ElsIf Items.Find("CostAllocationPicture" + Ct).Picture = Items.Red.Picture Then				
				ThisForm["TextErrorCostAllocation" + Ct] = NStr("en = 'Cost allocation is required.'; ru = '?????????????????? ?????????????????? ?????????????????????????? ????????????.';pl = 'Wymagana jest alokacja koszt??w.';es_ES = 'Se requiere una asignaci??n de costes.';es_CO = 'Se requiere una asignaci??n de costes.';tr = 'Maliyet da????t??m?? gerekli.';it = '?? richiesta l''allocazione dei costi.';de = 'Kostenzuordnung ist erforderlich.'");			
			EndIf;			
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorDirectCostCalculation" + Ct]) Then
			If Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs are calculated.'; ru = '???????????? ???????????? ???????????? ???????????????? ??????????????!';pl = 'Koszty bezpo??rednie s?? obliczone.';es_ES = 'Costes directos se han calculado.';es_CO = 'Costes directos se han calculado.';tr = 'Direkt giderler hesapland??.';it = 'I costi diretti sono stati calcolati.';de = 'Direkte Kosten werden berechnet.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is not required.'; ru = '???????????? ???????????? ???????????? ???? ??????????????????.';pl = 'Obliczanie koszt??w bezpo??rednich nie jest wymagane.';es_ES = 'No se requiere el c??lculo de costes directos.';es_CO = 'No se requiere el c??lculo de costes directos.';tr = 'Do??rudan maliyet hesaplanmas?? gerekmiyor.';it = 'Il calcolo dei costi diretti non ?? necessaria.';de = 'Eine direkte Kostenberechnung ist nicht erforderlich.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct costs were not calculated.'; ru = '???????????? ???????????? ???????????? ???? ????????????????????????.';pl = 'Koszty bezpo??rednie nie zosta??y obliczone.';es_ES = 'Costes directos no se han calculado.';es_CO = 'Costes directos no se han calculado.';tr = 'Direkt giderler hesaplanmad??.';it = 'I costi diretti non sono stati calcolati.';de = 'Direkte Kosten wurden nicht berechnet.'");
			ElsIf Items.Find("DirectCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorDirectCostCalculation" + Ct] = NStr("en = 'Direct cost calculation is required.'; ru = '?????????????????? ?????????????????? ???????????? ???????????? ????????????.';pl = 'Wymagane jest bezpo??rednie obliczenie koszt??w.';es_ES = 'No se requiere el c??lculo de costes directos.';es_CO = 'No se requiere el c??lculo de costes directos.';tr = 'Do??rudan maliyet hesab?? gerekiyor.';it = 'E'' richiesto il calcolo dei costi diretti.';de = 'Direkte Kostenberechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorActualCostCalculation" + Ct]) Then
			If Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost is calculated successfully.'; ru = '???????????? ?????????????????????? ?????????????????????????? ???????????????? ??????????????!';pl = 'Obliczenie faktycznego kosztu wykonano pomy??lnie.';es_ES = 'Coste actual se ha calculado con ??xito.';es_CO = 'Coste actual se ha calculado con ??xito.';tr = 'Ger??ekle??en maliyet ba??ar??yla hesapland??.';it = 'Il costo effettivo ?? stato calcolato con successo.';de = 'Selbstkosten werden erfolgreich berechnet.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is not required.'; ru = '???????????? ?????????????????????? ?????????????????????????? ???? ??????????????????.';pl = 'Obliczenie faktycznego kosztu nie jest wymagany.';es_ES = 'No se requiere el c??lculo del coste actual.';es_CO = 'No se requiere el c??lculo del coste actual.';tr = 'Ger??ekle??en maliyet hesaplamas?? zorunlu de??il.';it = 'Il calcolo del costo effettivo non ?? necessario.';de = ' Selbstkostenberechnung ist nicht erforderlich.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation was not performed.'; ru = '???????????? ?????????????????????? ?????????????????????????? ???? ????????????????????????.';pl = 'Obliczenie faktycznego kosztu nie zosta??o wykonane.';es_ES = 'C??lculo del coste actual no se ha realizado.';es_CO = 'C??lculo del coste actual no se ha realizado.';tr = 'Ger??ekle??en maliyet hesaplamas?? yap??lmad??.';it = 'Il calcolo del costo effettivo non ?? stato eseguito.';de = 'Selbstkostenberechnung wurde nicht durchgef??hrt.'");
			ElsIf Items.Find("ActualCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorActualCostCalculation" + Ct] = NStr("en = 'Actual cost calculation is required.'; ru = '?????????????????? ?????????????????? ???????????? ?????????????????????? ??????????????????????????.';pl = 'Wymagane jest obliczanie koszt??w bezpo??rednich.';es_ES = 'Se requiere el c??lculo del coste actual.';es_CO = 'Se requiere el c??lculo del coste actual.';tr = 'Ger??ekle??en maliyet hesaplamas?? gerekiyor.';it = 'E'' richiesto il calcolo del costo effettivo.';de = 'Die Selbstkostenberechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorFinancialResultCalculation" + Ct]) Then
			If Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Financial result is calculated.'; ru = '???????????? ?????????????????????? ???????????????????? ???????????????? ??????????????!';pl = 'Wynik finansowy zosta?? obliczony pomy??lnie.';es_ES = 'Resultado financiero se ha calculado.';es_CO = 'Resultado financiero se ha calculado.';tr = 'Finansal sonu?? hesaplan??yor.';it = 'Risultato finanziario calcolato.';de = 'Das finanzielle Ergebnis wird berechnet.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Temporary accounts closing is not required.'; ru = '???????????? ?????????????????????? ???????????????????? ???? ??????????????????.';pl = 'Zamkni??cie tymczasowych kont nie jest wymagane.';es_ES = 'No se requiere el cierre temporal de las cuentas.';es_CO = 'No se requiere el cierre temporal de las cuentas.';tr = 'Ge??ici hesaplar??n kapat??lmas?? gerekli de??ildir.';it = 'La chiusura dei conti temporanei non ?? richiesta';de = 'Abschlie??en von tempor??ren Konten nicht erforderlich.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Accounts were not closed.'; ru = '?????????? ???? ???????? ??????????????.';pl = 'Konta nie zosta??y zamkni??te.';es_ES = 'Las cuentas no se han cerrado.';es_CO = 'Las cuentas no se han cerrado.';tr = 'Hesaplar kapat??lmad??.';it = 'I conti  non sono stati chiusi.';de = 'Konten wurden nicht geschlossen.'");
			ElsIf Items.Find("FinancialResultCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorFinancialResultCalculation" + Ct] = NStr("en = 'Temporary accounts closing is required.'; ru = '?????????????????? ???????????? ?????????????????????? ????????????????????.';pl = 'Zamkni??cie tymczasowych kont jest wymagane.';es_ES = 'Se requiere el cierre temporal de las cuentas.';es_CO = 'Se requiere el cierre temporal de las cuentas.';tr = 'Ge??ici hesaplar??n kapat??lmas?? gerekiyor.';it = 'La chiusura dei conti temporanei ?? richiesta.';de = 'Abschlie??en von tempor??ren Konten ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorExchangeDifferencesCalculation" + Ct]) Then
			If Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are successfully calculated.'; ru = '???????????? ???????????????? ???????????? ???????????????? ??????????????!';pl = 'R????nice kursowe zosta??y obliczone pomy??lnie.';es_ES = 'Diferencias de tipos de cambios se han calculado con ??xito.';es_CO = 'Diferencias de tipos de cambios se han calculado con ??xito.';tr = 'D??viz kuru farkl??l??klar?? ba??ar??yla hesapland??.';it = 'Le differenze di cambio sono state calcolate con successo.';de = 'Wechselkursdifferenzen werden erfolgreich berechnet.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not required.'; ru = '???????????? ???????????????? ???????????? ???? ??????????????????.';pl = 'Nie jest wymagane obliczenie r????nic kursowych.';es_ES = 'No se requieren las diferencias de tipos de cambio.';es_CO = 'No se requieren las diferencias de tipos de cambio.';tr = 'D??viz kuru farkl??l??klar?? gerekmiyor.';it = 'Le differenze di cambio non sono richieste.';de = 'Wechselkursdifferenzen sind nicht erforderlich.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are not calculated.'; ru = '???????????? ???????????????? ???????????? ???? ????????????????????????.';pl = 'R????nice kursowe nie s?? obliczane.';es_ES = 'Diferencias de tipos de cambio no se han calculado.';es_CO = 'Diferencias de tipos de cambio no se han calculado.';tr = 'D??viz kuru farkl??l??klar?? hesaplanmad??.';it = 'Le differenze di cambio non sono state calcolate.';de = 'Wechselkursdifferenzen werden nicht berechnet.'");
			ElsIf Items.Find("ExchangeDifferencesCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorExchangeDifferencesCalculation" + Ct] = NStr("en = 'Exchange rate differences are required.'; ru = '?????????????????? ?????????????????? ???????????? ???????????????? ????????????.';pl = 'Wymagane jest obliczenie r????nic kursowych.';es_ES = 'Se requieren las diferencias de tipos de cambio.';es_CO = 'Se requieren las diferencias de tipos de cambio.';tr = 'D??viz kuru farkl??l??klar?? gerekiyor.';it = 'Sono richieste le differenze dei tassi di cambio.';de = 'Wechselkursdifferenzen sind erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorCalculationPrimecostInRetail" + Ct]) Then
			If Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is successfully calculated.'; ru = '???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????) ???????????????? ??????????????!';pl = 'KWS dla terminal??w POS z metod?? inwentaryzacji detalicznej zosta?? pomy??lnie obliczony.';es_ES = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista se ha calculado con ??xito.';es_CO = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista se ha calculado con ??xito.';tr = 'Envanter perakende y??ntemli POS i??in SMM ba??ar??yla hesapland??.';it = 'Il costo del venduto per Punto Vendita con metodo al dettaglio ?? stato calcolato con successo.';de = 'Wareneinsatz f??r POS mit Inventurmethode (Einzelhandel) wurde erfolgreich berechnet.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is not required.'; ru = '???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????) ???? ??????????????????.';pl = 'Obliczenie KWS dla punkt??w sprzeda??y z metod?? inwentaryzacji detalicznej nie jest wymagane.';es_ES = 'No se requiere el c??lculo del coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';es_CO = 'No se requiere el c??lculo del coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';tr = 'Envanter perakende y??ntemli POS i??in SMM hesaplamas?? gerekli de??il.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non ?? richiesto.';de = 'Eine Wareneinsatz-Berechnung f??r POS mit Inventurmethode (Einzelhandel) ist nicht erforderlich.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS for POS with retail inventory method is not calculated.'; ru = '???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????) ???? ????????????????????????.';pl = 'KWS dla punkt??w sprzeda??y z metod?? inwentaryzacji detalicznej nie jest obliczony.';es_ES = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista no se ha calculado.';es_CO = 'Coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista no se ha calculado.';tr = 'Envanter perakende y??ntemli POS i??in SMM hesaplanmad??.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio non ?? stato calcolato.';de = 'Wareneinsatz f??r POS mit Inventurmethode (Einzelhandel) werden nicht berechnet.'");
			ElsIf Items.Find("RetailCostCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorCalculationPrimecostInRetail" + Ct] = NStr("en = 'COGS calculation for POS with retail inventory method is required.'; ru = '?????????????????? ?????????????????? ???????????? ?????????????????????????? ?? ?????????????? (???????????????? ????????).';pl = 'Obliczenie KWS dla punkt??w sprzeda??y terminal??w POS z metod?? inwentaryzacji detalicznej jest wymagane.';es_ES = 'Se requiere el coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';es_CO = 'Se requiere el coste de mercanc??as vendidas para el TPV con el m??todo de inventario de la venta minorista.';tr = 'Envanter perakende y??ntemli POS i??in SMM hesaplamas?? gerekli.';it = 'Il calcolo del costo del venduto per il Punto Vendita con metodo di vendita al dettaglio ?? richiesto.';de = 'Eine Wareneinsatz-Berechnung f??r POS mit Inventurmethode (Einzelhandel) ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorAccrueDepreciation" + Ct]) Then
			If Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is accrued.'; ru = '???????????????????? ?????????????????????? ?????????????????? ??????????????!';pl = 'Amortyzacja zosta??a naliczona pomy??lnie.';es_ES = 'Depreciaci??n se ha acumulado.';es_CO = 'Depreciaci??n se ha acumulado.';tr = 'Amortisman tahakkuk etti.';it = 'L''ammortamento ?? maturato.';de = 'Abschreibungen sind angefallen.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not required.'; ru = '???????????????????? ?????????????????????? ???? ??????????????????.';pl = 'Amortyzacja nie wymagana.';es_ES = 'No se requiere la depreciaci??n.';es_CO = 'No se requiere la depreciaci??n.';tr = 'Amortisman gerekmiyor.';it = 'L''ammortamento non ?? necessario.';de = 'Abschreibung ist nicht erforderlich.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is not accrued.'; ru = '???????????????????? ?????????????????????? ???? ??????????????????????????.';pl = 'Amortyzacja nie by??a wykonana.';es_ES = 'Depreciaci??n no se ha acumulado.';es_CO = 'Depreciaci??n no se ha acumulado.';tr = 'Amortisman tahakkuk etmedi.';it = 'L''ammortamento non ?? maturato.';de = 'Abschreibung ist nicht angefallen.'");
			ElsIf Items.Find("AccrueDepreciationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorAccrueDepreciation" + Ct] = NStr("en = 'Depreciation is required.'; ru = '?????????????????? ?????????????????? ???????????????????? ??????????????????????.';pl = 'Amortyzacja wymagana.';es_ES = 'Se requiere la depreciaci??n.';es_CO = 'Se requiere la depreciaci??n.';tr = 'Amortisman gerekiyor.';it = 'E'' richiesto l''ammortamento.';de = 'Abschreibung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVerifyTaxInvoices" + Ct]) Then
			If Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoices are verified.'; ru = '???????????????? ?????????????????? ???????????????? ??????????????????.';pl = 'Faktury VAT s?? zweryfikowane.';es_ES = 'Facturas de impuestos se han verificado.';es_CO = 'Facturas fiscales se han verificado.';tr = 'Vergi faturalar?? do??ruland??.';it = 'Le fatture fiscali sono verificate.';de = 'Steuerrechnungen werden verifiziert.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not required.'; ru = '???????????????? ?????????????????? ???????????????? ???? ??????????????????.';pl = 'Weryfikacja faktury VAT nie jest wymagana.';es_ES = 'No se requiere la verificaci??n de facturas de impuestos.';es_CO = 'No se requiere la verificaci??n de facturas fiscales.';tr = 'Vergi faturas?? do??rulamas?? gerekmiyor.';it = 'Il controllo della fattura fiscale non ?? necessario.';de = 'Die ??berpr??fung der Steuerrechnung ist nicht erforderlich.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is not accrued.'; ru = '???????????????? ?????????????????? ???????????????? ???? ??????????????????????????.';pl = 'Weryfikacja faktury VAT nie by??a wykonana.';es_ES = 'Verificaci??n de facturas de impuestos no se ha acumulado.';es_CO = 'Verificaci??n de facturas fiscales no se ha acumulado.';tr = 'Vergi faturas??n??n do??rulanmas?? tahakkuk etmedi.';it = 'Il controllo della fattura fiscale non ?? stato maturato.';de = 'Steuerrechnungspr??fung ist nicht angefallen.'");
			ElsIf Items.Find("VerifyTaxInvoicesPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVerifyTaxInvoices" + Ct] = NStr("en = 'Tax invoice verification is required.'; ru = '?????????????????? ?????????????????? ???????????????? ?????????????????? ????????????????.';pl = 'Weryfikacja faktury VAT jest wymagana.';es_ES = 'Se requiere la verificaci??n de facturas de impuestos.';es_CO = 'Se requiere la verificaci??n de facturas fiscales.';tr = 'Vergi faturas?? do??rulamas?? gerekiyor.';it = 'Il controllo della Fattura Fiscale ?? richiesto.';de = 'Die ??berpr??fung der Steuerrechnung ist erforderlich.'");
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(ThisForm["TextErrorVATPayableCalculation" + Ct]) Then
			If Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Green.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable is calculated.'; ru = '?????? ?? ???????????? ??????????????????.';pl = 'VAT nale??ny jest obliczany.';es_ES = 'El IVA a pagar se ha calculado.';es_CO = 'El IVA a pagar se ha calculado.';tr = '??denecek KDV hesapland??.';it = 'IVA da pagare ?? stata calcolata.';de = 'Die zu zahlende USt. wird berechnet.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.GreenIsNotRequired.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is not required.'; ru = '???????????? ?????? ?? ???????????? ???? ??????????????????.';pl = 'Obliczenie VAT nale??nego nie jest wymagane.';es_ES = 'No se requiere el c??lculo del IVA a pagar.';es_CO = 'No se requiere el c??lculo del IVA a pagar.';tr = '??denecek KDV hesaplamas?? gerekmiyor.';it = 'Il calcolo dell''IVA da pagare non ?? richiesto.';de = 'Eine Berechnung der zu zahlenden USt. ist nicht erforderlich.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Gray.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable was not calculated.'; ru = '?????? ?? ???????????? ???? ?????? ??????????????????.';pl = 'VAT nale??ny nie zosta?? obliczony.';es_ES = 'El IVA a pagar no se ha calculado.';es_CO = 'El IVA a pagar no se ha calculado.';tr = '??denecek KDV hesaplanmad??.';it = 'L''IVA da pagare non ?? stato calcolato.';de = 'Die zu zahlende USt. wurde nicht berechnet.'");
			ElsIf Items.Find("VATPayableCalculationPicture" + Ct).Picture = Items.Red.Picture Then
				ThisForm["TextErrorVATPayableCalculation" + Ct] = NStr("en = 'VAT payable calculation is required.'; ru = '?????????????????? ???????????? ?????? ?? ????????????.';pl = 'Obliczenie VAT nale??nego jest wymagane.';es_ES = 'Se requiere el c??lculo del IVA a pagar.';es_CO = 'Se requiere el c??lculo del IVA a pagar.';tr = '??denecek KDV hesaplamas?? gerekli.';it = 'Il calcolo dell''IVA da pagare ?? richiesto.';de = 'Eine Berechnung der zu zahlenden USt. ist erforderlich.'");
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
				NStr("en = 'Month-end closing is not required as there is no data for calculation.'; ru = '???????????????? ???????????? ???? ??????????????????, ??.??. ?????? ???????????? ?????? ??????????????.';pl = 'Zamkni??cie miesi??ca nie jest wymagane, poniewa?? nie ma danych do obliczenia.';es_ES = 'Cierre del fin de mes no se requiere, porque no hay datos para el c??lculo.';es_CO = 'Cierre del fin de mes no se requiere, porque no hay datos para el c??lculo.';tr = 'Hesaplanacak veri olmad??????ndan ay sonu kapan?????? gerekmiyor.';it = 'La chiusura mensile non ?? necessaria in quanto non vi sono dati per il calcolo.';de = 'Monatsabschluss ist nicht erforderlich, da keine Daten zur Berechnung vorhanden sind.'");
			
		Else
			
			If Items["M" + Ct].Picture = Items.Green.Picture Then
				Items.Find("DecorationPerformClosingNotNeeded" + Ct).Title = 
					NStr("en = 'The month-end closing is completed.
					|To view the list of month-end closing documents for this company and this year, click ""Documents""'; 
					|ru = '???????????????? ???????????? ??????????????????.
					|?????? ?????????????????? ???????????? ???????????????????? ???????????????? ???????????? ?????? ???????? ?????????????????????? ???? ???????? ?????? ?????????????? ""??????????????????""';
					|pl = 'Zamkni??cie miesi??ca jest zako??czone.
					|Aby zobaczy?? list?? dokument??w o zamkni??ciu miesi??ca dla tej firmy i tego roku, kliknij ""Dokumenty""';
					|es_ES = 'El cierre de fin de mes se ha completado.
					|Para ver la lista de los documentos de cierre del mes de esta empresa y de este a??o, hacer clic en ""Documentos"".';
					|es_CO = 'El cierre de fin de mes se ha completado.
					|Para ver la lista de los documentos de cierre del mes de esta empresa y de este a??o, hacer clic en ""Documentos"".';
					|tr = 'Ay sonu kapan?????? tamamland??.
					|Bu i?? yerinin ve bu y??l??n ay sonu kapan?????? belge listesini g??r??nt??lemek i??in ''''Belgeler'''' butonuna t??klay??n.';
					|it = 'La chiusura di fine periodo ?? completata.
					| Per visualizzare l''elenco dei documenti di chiusura di fine periodo per questa azienda e quest''anno, cliccare su ""Documenti""';
					|de = 'Der Monatsabschluss ist abgeschlossen.
					|Um die Liste der Monatsabschlussdokumente f??r diese Firma und dieses Jahr anzuschauen, klicken Sie auf ""Dokumente""'");
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
		
		TextQuery = NStr("en = 'You have changed the settings for this ""Month-end closing"" document. To apply these changes and repost the document, click ""Continue"". To cancel the changes, click ""Cancel"".'; ru = '???? ???????????????? ?????????????????? ?????? ?????????? ?????????????????? ""???????????????? ????????????"". ?????????? ?????????????????? ?????????????????? ?? ???????????????? ???????????????? ????????????, ?????????????? ""????????????????????"". ?????????? ???????????????? ??????????????????, ?????????????? ""????????????"".';pl = 'Ustawienia dla tego dokumentu ""Zamkni??cie miesi??ca"" zosta??y zmienione. Aby zastosowa?? te zmiany i ponownie zatwierdzi?? dokument, kliknij ""Kontynuuj"". Aby anulowa?? zmiany, kliknij ""Anuluj"".';es_ES = 'Ha cambiado la configuraci??n de este documento de ""Cierre del mes"". Para aplicar estos cambios y volver a publicar el documento, haga clic en ""Continuar"". Para cancelar los cambios, haga clic en ""Cancelar"".';es_CO = 'Ha cambiado la configuraci??n de este documento de ""Cierre del mes"". Para aplicar estos cambios y volver a publicar el documento, haga clic en ""Continuar"". Para cancelar los cambios, haga clic en ""Cancelar"".';tr = 'Bu ""Ay sonu kapan??????"" belgesinin ayarlar??n?? de??i??tirdiniz. De??i??ikliklerin uygulanmas?? ve belgenin yeniden kaydedilmesi i??in ""Devam""a t??klay??n. De??i??iklikleri iptal etmek i??in ""??ptal""e t??klay??n.';it = 'Sono state modificate le impostazioni per questo documento ""Chiusura mensile"". Per applicare queste modifiche e ripubblicare il documento, cliccare su ""Continuare"". Per annullare le modifiche, cliccare su ""Annullare"".';de = 'Sie haben die Einstellungen f??r dieses Dokument ""Monatsabschluss"" ge??ndert. Um diese ??nderungen zu verwenden und das Dokument neu zu buchen, klicken Sie auf ""Weiter"". Um diese ??nderungen zu verwerfen, klicken Sie auf ""Abbrechen"".'"); 
		
		Mode = New ValueList;
		Mode.Add(DialogReturnCode.OK, NStr("en = 'Continue'; ru = '????????????????????';pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continuare';de = 'Weiter'"));
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
			NStr("en = 'Cannot close the month. It is included in the accounting period that is already closed.'; ru = '???? ?????????????? ?????????????? ??????????. ???? ?????????????? ?? ?????? ???????????????? ?????????????? ????????????.';pl = 'Nie zamkn???? miesi??ca. Jest on w????czony do ju?? zamkni??tego okresu rozliczeniowego.';es_ES = 'No se puede cerrar el mes. Se incluye en el per??odo contable que ya est?? cerrado.';es_CO = 'No se puede cerrar el mes. Se incluye en el per??odo contable que ya est?? cerrado.';tr = 'Ay kapat??lam??yor. Zaten kapat??lm???? olan bir hesap d??nemine dahil.';it = 'Impossibile chiudere il mese. ?? incluso nel periodo contabile gi?? chiuso.';de = 'Fehler beim Monatsabschluss. Der bereits abgeschlossene Buchhaltungszeitraum enth??lt ihn.'"));
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