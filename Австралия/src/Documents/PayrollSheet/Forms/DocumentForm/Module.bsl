#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure fills tabular section Employees balance by charges.
//
Procedure FillByBalanceAtServer()	
	
	Document = FormAttributeToValue("Object");
	Document.FillByBalanceAtServer();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServer
// Procedure fills tabular section Employees by department.
//
Procedure FillByDepartmentAtServer()	
	
	Document = FormAttributeToValue("Object");
	Document.FillByDepartmentAtServer();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure fills tabular section Employees balance by charges.
//
Procedure RecalculateAmountByCurrency(TabularSectionRow, ChangedEarning, ChangedForExport, AdditionalParameters = Undefined)
	
	//
	// If both currencies are changed, calculation of payment amount is done by Earning amount
	//
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
	
	If ChangedEarning Then
		
		If AdditionalParameters <> Undefined Then
			
			TabularSectionRow.SettlementsAmount = CurrenciesExchangeRatesClientServer.ConvertCurrencies(TabularSectionRow.SettlementsAmount, ExchangeRateMethod, AdditionalParameters.SettlementsCurrencyBeforeChange, Object.SettlementsCurrency, AdditionalParameters.ExchangeRateBeforeChange, Object.ExchangeRate, AdditionalParameters.MultiplicityBeforeChange, Object.Multiplicity);
			
		EndIf;
		
		TabularSectionRow.PaymentAmount = CurrenciesExchangeRatesClientServer.ConvertCurrencies(TabularSectionRow.SettlementsAmount, ExchangeRateMethod, Object.SettlementsCurrency, Object.DocumentCurrency, Object.ExchangeRate, RateDocumentCurrency, Object.Multiplicity, RepetitionDocumentCurrency);
		
	ElsIf ChangedForExport Then
		
		If AdditionalParameters <> Undefined Then
			
			TabularSectionRow.PaymentAmount = CurrenciesExchangeRatesClientServer.ConvertCurrencies(TabularSectionRow.PaymentAmount, ExchangeRateMethod, AdditionalParameters.DocumentCurrencyBeforeChange, Object.DocumentCurrency, AdditionalParameters.ExchangeRateDocumentCurrencyBeforeChange, RateDocumentCurrency, AdditionalParameters.MultiplicityDocumentCurrencyBeforeChange, RepetitionDocumentCurrency);
			
		EndIf;
		
		TabularSectionRow.SettlementsAmount = CurrenciesExchangeRatesClientServer.ConvertCurrencies(TabularSectionRow.PaymentAmount, ExchangeRateMethod, Object.DocumentCurrency, Object.SettlementsCurrency, RateDocumentCurrency, Object.ExchangeRate, RepetitionDocumentCurrency, Object.Multiplicity);
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills tabular section Employees balance by charges.
//
Procedure SetVisibleFromCurrency()
	
	SettlementsCurrencyDiffersFromDocumentCurrency = (Object.DocumentCurrency <> Object.SettlementsCurrency);
	
	CommonClientServer.SetFormItemProperty(Items, "EmployeesSettlementsAmount", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	CommonClientServer.SetFormItemProperty(Items, "EmployeesTotalAmountSettlements", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	CommonClientServer.SetFormItemProperty(Items, "EmployeesSettlementsCurrency", "Visible", SettlementsCurrencyDiffersFromDocumentCurrency);
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtClient
// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	ParametersStructure.Insert("RateDocumentCurrency",		RateDocumentCurrency);
	ParametersStructure.Insert("RepetitionDocumentCurrency",RepetitionDocumentCurrency);
	
	ParametersStructure.Insert("SettlementsCurrency",			Object.SettlementsCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",				Object.Multiplicity);
	
	ParametersStructure.Insert("Company",				ParentCompany);
	ParametersStructure.Insert("DocumentDate",			Object.Date);
	ParametersStructure.Insert("RecalculatePricesByCurrency",	False);
	ParametersStructure.Insert("WereMadeChanges",	False);
	
	StructurePricesAndCurrency = Undefined;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("SettlementsCurrencyBeforeChange", Object.SettlementsCurrency);
	AdditionalParameters.Insert("ExchangeRateBeforeChange" ,Object.ExchangeRate);
	AdditionalParameters.Insert("MultiplicityBeforeChange" ,Object.Multiplicity);
	
	AdditionalParameters.Insert("DocumentCurrencyBeforeChange", Object.DocumentCurrency);
	AdditionalParameters.Insert("ExchangeRateDocumentCurrencyBeforeChange" ,RateDocumentCurrency);
	AdditionalParameters.Insert("MultiplicityDocumentCurrencyBeforeChange" ,RepetitionDocumentCurrency);
	
	OpenForm("Document.PayrollSheet.Form.CurrencyForm", ParametersStructure,,,,, New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, AdditionalParameters), FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(Result, AdditionalParameters) Export
	
	StructurePricesAndCurrency = Result;
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.DocumentCurrency		= StructurePricesAndCurrency.DocumentCurrency;
		RateDocumentCurrency			= StructurePricesAndCurrency.RateDocumentCurrency;
		RepetitionDocumentCurrency	= StructurePricesAndCurrency.RepetitionDocumentCurrency;
		
		Object.SettlementsCurrency 	= StructurePricesAndCurrency.SettlementsCurrency;
		Object.ExchangeRate 			= StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity 		= StructurePricesAndCurrency.Multiplicity;
		
		// Recalculate prices by currency.
		If StructurePricesAndCurrency.RecalculatePricesByCurrency Then
			
			For Each TabularSectionRow In Object.Employees Do
				
				RecalculateAmountByCurrency(TabularSectionRow, StructurePricesAndCurrency.ChangedCurrencySettlements, StructurePricesAndCurrency.ChangedDocumentCurrency, AdditionalParameters);
				
			EndDo; 
			
		ElsIf StructurePricesAndCurrency.SettlementsCurrency <> AdditionalParameters.SettlementsCurrencyBeforeChange 
			AND StructurePricesAndCurrency.DocumentCurrency <> AdditionalParameters.DocumentCurrencyBeforeChange Then
			
			// Skip
			
		ElsIf StructurePricesAndCurrency.SettlementsCurrency <> AdditionalParameters.SettlementsCurrencyBeforeChange 
			OR StructurePricesAndCurrency.DocumentCurrency <> AdditionalParameters.DocumentCurrencyBeforeChange Then
			
			For Each TabularSectionRow In Object.Employees Do
				
				RecalculateAmountByCurrency(TabularSectionRow, False, True, AdditionalParameters);
				
			EndDo; 
			
		EndIf;
		
		SetVisibleFromCurrency();
		
	EndIf;
	
	// Fill in form data.
	PricesAndCurrency = NStr("en = 'Doc %1 • Beg. %2'; ru = 'Док %1 • Нач. %2';pl = 'Dok. %1 • Pocz. %2';es_ES = 'Documento %1 • Inicio %2';es_CO = 'Documento %1 • Inicio %2';tr = 'Dok. %1 • Baş. %2';it = 'Doc. %1 • In. %2';de = 'Dok %1 • Beg. %2'");
	PricesAndCurrency = StringFunctionsClientServer.SubstituteParametersToString(PricesAndCurrency, TrimAll(String(Object.DocumentCurrency)), TrimAll(String(Object.SettlementsCurrency)));
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not (Parameters.FillingValues.Property("RegistrationPeriod") AND ValueIsFilled(Parameters.FillingValues.RegistrationPeriod)) Then
		
		Object.RegistrationPeriod 	= BegOfMonth(CurrentSessionDate());
		
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		DocumentCurrencyRate = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
		Object.ExchangeRate = DocumentCurrencyRate.Rate;
		Object.Multiplicity = DocumentCurrencyRate.Repetition;
		
	EndIf;
	
	If Object.SettlementsCurrency = Object.DocumentCurrency Then
		
		RateDocumentCurrency = Object.ExchangeRate;
		RepetitionDocumentCurrency = Object.Multiplicity;
		
	Else
		
		DocumentCurrencyRate = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
		RateDocumentCurrency = DocumentCurrencyRate.Rate;
		RepetitionDocumentCurrency = DocumentCurrencyRate.Repetition;
		
	EndIf;
	
	// Fill in form data.
	PricesAndCurrency = NStr("en = 'Doc. %1 • Beg. %2'; ru = 'Док. %1 • Нач. %2';pl = 'Dok. %1 • Pocz. %2';es_ES = 'Documento %1 • Inicio %2';es_CO = 'Documento %1 • Inicio %2';tr = 'Dok. %1 • Baş. %2';it = 'Doc. %1 • In. %2';de = 'Dok. %1 • Beg. %2'");
	PricesAndCurrency = StringFunctionsClientServer.SubstituteParametersToString(PricesAndCurrency, TrimAll(String(Object.DocumentCurrency)), TrimAll(String(Object.SettlementsCurrency)));
	
	SetVisibleFromCurrency();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			Items.EmployeesEmployeeCode.Visible = False;
		EndIf; 
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure - FillInAndCalculateExecute event handler of the form.
//
Procedure FillByBalance(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Department is not populated.'; ru = 'Не заполнено подразделение!';pl = 'Nie wypełniono pola dział.';es_ES = 'Departamento no está poblado.';es_CO = 'Departamento no está poblado.';tr = 'Bölüm doldurulmadı.';it = 'Il reparto non è inserito.';de = 'Abteilung ist nicht ausgefüllt.'");
		Message.Field = "Object.StructuralUnit";
 		Message.Message();
		
		Return;
		
	EndIf;
	
	FillByBalanceAtServer();		
	
EndProcedure

&AtClient
Procedure FillByDepartment(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Department is not populated.'; ru = 'Не заполнено подразделение!';pl = 'Nie wypełniono pola oddziału.';es_ES = 'Departamento no está poblado.';es_CO = 'Departamento no está poblado.';tr = 'Bölüm doldurulmadı.';it = 'Il reparto non è inserito.';de = 'Abteilung ist nicht ausgefüllt.'");
		Message.Field = "Object.StructuralUnit";
 		Message.Message();
		
		Return;
		
	EndIf;
	
	FillByDepartmentAtServer();
	
EndProcedure

&AtClient
// Procedure - Management event handler of RegistrationPeriod attribute
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

&AtClient
// Procedure - StartChoice event handler of RegistrationPeriod attribute
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the SettlementsAmount input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure SettlementsAmountOnChange(Item)
	
	RecalculateAmountByCurrency(Items.Employees.CurrentData, True, False);
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the SettlementsAmount input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure EmployeesPaymentAmountOnChange(Item)
	
	RecalculateAmountByCurrency(Items.Employees.CurrentData, False, True);
	
EndProcedure

&AtClient
// Procedure - Click event handler of PricesAndCurrency field.
//
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion
