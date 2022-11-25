
#Region GeneralPurposeProceduresAndFunctions

// Function places the Accruals tabular section into
// the temporary storage
// and returns the address
&AtServer
Function PlaceAccrualsToStorage()

	AddressInStorage = PutToTempStorage(Object.Accruals.Unload(), UUID);
	Return AddressInStorage;

EndFunction

// Procedure receives the Accruals tabular section from the temporary storage.
//
&AtServer
Procedure ReceiveAccrualsFromStorage(AccrualAddressInStorage)

	Object.Accruals.Load(GetFromTempStorage(AccrualAddressInStorage));

EndProcedure

#EndRegion

#Region ProceduresEventHandlersForms

// Procedure - handler of the WhenCreatingOnServer event.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	OperationKindWhenChangingOnServer();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	TransactionKindAccrualsForCredits = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

// Procedure - handler of the WhenOpening event.
//
&AtClient
Procedure OnOpen(Cancel)
	
	OperationType = Object.OperationType;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)

	If TypeOf(SelectedValue) = Type("Structure") Then
		
		If SelectedValue.Property("AccrualAddressInStorage") Then
			ReceiveAccrualsFromStorage(SelectedValue.AccrualAddressInStorage);
			Modified = True;
			
			If Object.Accruals.Count() = 0 Then
				
				LineForOperationKind = ?(Object.OperationType = TransactionKindAccrualsForCredits, 
					NStr("en = 'credits'; ru = 'кредитам';pl = 'kredyty';es_ES = 'créditos';es_CO = 'créditos';tr = 'alacaklar';it = 'crediti';de = 'guthaben'"), 
					NStr("en = 'loans'; ru = 'займам';pl = 'rozliczenia z tytułu kredytów i pożyczek';es_ES = 'préstamos';es_CO = 'préstamos';tr = 'krediler';it = 'prestiti';de = 'darlehen'"));
				
				ShowMessageBox(Undefined, 
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Interest accrual period is out of loan installments'; ru = 'Период начисления процентов не попадает в график платежей.';pl = 'Okres naliczania odsetek jest poza pożyczkami kredytowymi';es_ES = 'Período de acumulación del interés está fuera de la cuota de préstamo';es_CO = 'Período de acumulación del interés está fuera de la cuota de préstamo';tr = 'Tahakkuk eden faiz süresi kredi taksitlerinin dışında';it = 'Il periodo di maturazione degli interessi è fuori dalle rate del prestito';de = 'Der Zinsabgrenzungszeitraum ist außerhalb der Darlehensraten'"),
						LineForOperationKind));
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - handler of the WhenReadingOnServer event.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

// Procedure handler of the PopulationCheckProcessingOnServer event.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure handler of the BeforeWritingOnServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckCommisionWithLentToEmployee(Cancel);
	
	If Cancel Then
		Return;
	EndIf;

	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

#EndRegion

#Region CommandActionProcedures

// Procedure - handler of the PopulateAccruals command.
//
&AtClient
Procedure PopulateAccruals(Command)
	
	If Not ValueIsFilled(Object.OperationType) Then
		ShowMessageBox(Undefined, NStr("en = 'Operation is not specified.'; ru = 'Не указана операция!';pl = 'Nie określono operacji.';es_ES = 'Operación no está especificada.';es_CO = 'Operación no está especificada.';tr = 'İşlem belirtilmedi.';it = 'Operazione non specificata!';de = 'Operation ist nicht angegeben.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		ShowMessageBox(Undefined, NStr("en = 'Company is not specified.'; ru = 'Не указана организация!';pl = 'Nie określono organizacji.';es_ES = 'Empres no está especificada.';es_CO = 'Empres no está especificada.';tr = 'İş yeri belirtilmedi.';it = 'Azienda non specificata.';de = 'Firma ist nicht angegeben.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.StartDate) Then
		ShowMessageBox(Undefined, NStr("en = 'Accrual period start is not specified.'; ru = 'Не указано начало периода начислений!';pl = 'Nie określono początku okresu naliczania.';es_ES = 'Inicio del período de acumulación no está especificado.';es_CO = 'Inicio del período de acumulación no está especificado.';tr = 'Tahakkuk dönemi başlangıcı belirtilmemiş.';it = 'Il periodo di inizio accantonamento non è specificato!';de = ' Start des Abgrenzungszeitraums ist nicht angegeben.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.EndDate) Then
		ShowMessageBox(Undefined, NStr("en = 'Accrual period end is not specified.'; ru = 'Не указан конец периода начислений!';pl = 'Nie określono końca okresu naliczania.';es_ES = 'Fin del período de acumulación no está especificado.';es_CO = 'Fin del período de acumulación no está especificado.';tr = 'Tahakkuk dönemi sonu belirtilmemiş.';it = 'Il periodo di fine accantonamento non è specificato!';de = 'Ende des Abgrenzungszeitraums ist nicht angegeben.'"));
		Return;
	EndIf;
	
	If Not Object.EndDate > Object.StartDate Then
		ShowMessageBox(Undefined, NStr("en = 'Incorrect period is specified. Start date > End date.'; ru = 'Указан неверный период. Дата начала > Даты окончания!';pl = 'Określono nieprawidłowy okres. Data rozpoczęcia > Data zakończenia.';es_ES = 'Período incorrecto está especificado. Fecha del inicio > Fecha del fin.';es_CO = 'Período incorrecto está especificado. Fecha del inicio > Fecha del fin.';tr = 'Yanlış dönem belirtildi. Başlangıç tarihi > Bitiş tarihi.';it = 'E'' specificato un periodo non corretto. Data di inizio > Data di fine.';de = 'Falscher Zeitraum ist angegeben. Startdatum> Enddatum.'"));
		Return;
	EndIf;
	
	AccrualAddressInStorage = PlaceAccrualsToStorage();
	FilterParameters = New Structure("AccrualAddressInStorage,
		|Company,
		|Recorder,
		|OperationKind,
		|StartDate,
		|EndDate",
		AccrualAddressInStorage,
		Object.Company,
		Object.Ref,
		Object.OperationType,
		Object.StartDate,
		Object.EndDate);
	
	OpenForm("Document.LoanInterestCommissionAccruals.Form.FillingForm", 
		FilterParameters,
		ThisForm);
	
EndProcedure

#EndRegion

#Region ProceduresHandlersOfEventsHeaderAttributes

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

// Procedure - handler of the OnChange event of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	If OperationType <> Object.OperationType Then
		OperationType = Object.OperationType;
		
		Object.Accruals.Clear();
		
		OperationKindWhenChangingOnServer();
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)	
	Object.Number = "";	
EndProcedure

// Procedure - handler of the OnChange event of the OperationKind input field. Server part.
//
&AtServer
Procedure OperationKindWhenChangingOnServer()
	
	OperationType = Object.OperationType;
	
	If Object.OperationType = PredefinedValue("Enum.LoanAccrualTypes.AccrualsForLoansBorrowed") Then
		
		Items.Lender.Visible = True;
		Items.AccrualsBorrower.Visible = False;
		
	Else
		
		Items.Lender.Visible = False;
		Items.AccrualsBorrower.Visible = True;
		
	EndIf;
	
	If Object.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		
		NewArray = New Array();
		NewParameter = New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.Borrowed);
		
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.AccrualsLoanContract.ChoiceParameters = NewParameters;  
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the StartDate input field.
//
&AtClient
Procedure StartDateOnChange(Item)
	
	Object.EndDate = EndOfMonth(Object.StartDate);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region ProceduresHandlersOfEventsTabularSectionAttributes

// Procedure - handler of the OnChange event of the LoanContract attribute for the Accruals tabular section.
//
&AtClient
Procedure AccrualsLoanContractOnChange(Item)
	
	CurrentData = Items.Accruals.CurrentData;
	
	If CurrentData <> Undefined Then
		
		StructureData = AccrualsLoanContractWhenChangingOnServer(CurrentData.LoanContract, OperationType);
		
		CurrentData.SettlementsCurrency = StructureData.SettlementsCurrency;
		CurrentData.BusinessArea = StructureData.BusinessArea;
		CurrentData.Order = StructureData.Order;
		CurrentData.StructuralUnit = StructureData.StructuralUnit;
		
		If StructureData.Property("Lender") And Not ValueIsFilled(CurrentData.Lender) Then
			CurrentData.Lender = StructureData.Lender;
		EndIf;
		
		If StructureData.Property("Employee") And Not ValueIsFilled(CurrentData.Borrower) Then
			CurrentData.Borrower = StructureData.Employee;
		EndIf;
		
		If StructureData.Property("Borrower") And Not ValueIsFilled(CurrentData.Borrower) Then
			CurrentData.Borrower = StructureData.Borrower;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function AccrualsLoanContractWhenChangingOnServer(LoanContract, OperationType)
	
	LoanContractData = Common.ObjectAttributesValues(LoanContract, 
		"SettlementsCurrency, 
		|LoanKind, 
		|Counterparty, 
		|Employee,
		|BusinessArea,
		|Order,
		|StructuralUnit");
	
	StructureData = New Structure;
	StructureData.Insert("SettlementsCurrency", LoanContractData.SettlementsCurrency);
	StructureData.Insert("BusinessArea", LoanContractData.BusinessArea);
	StructureData.Insert("Order", LoanContractData.Order);
	StructureData.Insert("StructuralUnit", LoanContractData.StructuralUnit);
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed 
		And LoanContractData.LoanKind = Enums.LoanContractTypes.Borrowed Then
		
		StructureData.Insert("Lender", LoanContractData.Counterparty);
		
	ElsIf OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent
		And LoanContractData.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		
		StructureData.Insert("Employee", LoanContractData.Employee);
		
	ElsIf OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent
		And LoanContractData.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
		
		StructureData.Insert("Borrower", LoanContractData.Counterparty);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion

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

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtServer
Procedure CheckCommisionWithLentToEmployee(Cancel)
	
	If Object.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	TableTable.LoanContract AS LoanContract,
	|	TableTable.AmountType AS AmountType
	|INTO TemporaryTableTable
	|FROM
	|	&Accruals AS TableTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	TemporaryTableTable AS TableAccruals
	|		INNER JOIN Document.LoanContract AS DocumentLoanContract
	|		ON TableAccruals.LoanContract = DocumentLoanContract.Ref
	|WHERE
	|	TableAccruals.AmountType = &Commission
	|	AND DocumentLoanContract.LoanKind = &LoanKind";
	
	Query.SetParameter("Accruals",		Object.Accruals.Unload());
	Query.SetParameter("Commission",	Enums.LoanScheduleAmountTypes.Commission);
	Query.SetParameter("LoanKind",		Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	If Not Query.Execute().IsEmpty() Then
		CommonClientServer.MessageToUser(NStr("en = 'Commision is not applicable to loan contract with type
			|Lent to employee + <Loan contract> => Account type ""Commission"" is not applicable to a loan contract with the
			|""Lent to employee"" type. Select another account type or delete the line with this loan contract. Then try again.'; 
			|ru = 'Комиссия неприменима к договору кредита с типом
			|""Заем сотруднику"" + <Договор кредита> => Тип счета ""Комиссия"" неприменим к договору кредита с типом
			|""Заем сотруднику"". Выберите другой тип счета или удалите строку с этим договором кредита и повторите попытку.';
			|pl = 'Prowizja nie jest zastosowana do umowy pożyczki z typem
			|Pożyczka dla pracownika + <Umowa pożyczki> => Rodzaj konta ""Prowizja"" nie jest zastosowany do umowy pożyczki z typem
			|""Pożyczka dla pracownika"". Wybierz inny rodzaj konta lub usuń wiersz z tą umową pożyczki. Następnie spróbuj ponownie.';
			|es_ES = 'La comisión no es aplicable al contrato de préstamo con tipo
			|Prestado al empleado + <Contrato de préstamo> => El tipo de cuenta ""Comisión"" no es aplicable a un contrato de préstamo con el tipo 
			|""Prestado al empleado"". Seleccione otro tipo de cuenta o elimine la línea con este contrato de préstamo. Inténtelo de nuevo.';
			|es_CO = 'La comisión no es aplicable al contrato de préstamo con tipo
			|Prestado al empleado + <Contrato de préstamo> => El tipo de cuenta ""Comisión"" no es aplicable a un contrato de préstamo con el tipo 
			|""Prestado al empleado"". Seleccione otro tipo de cuenta o elimine la línea con este contrato de préstamo. Inténtelo de nuevo.';
			|tr = 'Çalışana borç verilen + <Kredi sözleşmesi> türündeki kredi sözleşmesine komisyon uygulanamıyor => ""Komisyon"" hesap türü, ""Çalışana borç verilen"" türündeki kredi sözleşmesine uygulanamıyor. Başka bir hesap türü seçin veya bu kredi sözleşmesini içeren satırı silin. Ardından, tekrar deneyin.';
			|it = 'La commissione non è applicabile al contratto di prestito con tipo
			|Prestito al dipendente + <Contratto di prestito> => Il tipo di conto ""Commissione"" non è applicabile a un contratto di prestito con il
			|tipo ""Prestito al dipendente"". Seleziona un altro tipo di conto o elimina la riga con questo contratto di prestito e riprova.';
			|de = 'Provisionszahlung ist für Darlehensvertrag mit dem Typ 
			|Geliehen an einen Mitarbeiter + <Darlehensvertrag> => Kontotyp ""Provisionszahlung"" ist für einen Darlehensvertrag mit dem Typ 
			|""Geliehen an einen Mitarbeiter"" nicht verwendbar, nicht verwendbar. Wählen Sie einen anderen Kontotyp aus oder löschen Sie die Zeile mit diesem Darlehensvertrag. Dann versuchen Sie erneut.'"),,,,Cancel);
	EndIf;
		
EndProcedure

#EndRegion