
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PostingDateFromDocument = Number(Object.PostingDateFromDocument);
	
	If NOT ValueIsFilled(Object.TransformationMethod) Then
		
		Object.TransformationMethod = Enums.TransformationMethods.CollectivePostingsByDates;
		
	EndIf;
	
	ChartOfAccounts = Object.ChartOfAccounts;
	ChartOfAccountsSource = Object.ChartOfAccountsSource;
	
	FillChartsOfAccountsList();
	
	If NOT ValueIsFilled(Object.Ref) Then
		DateOnChangeAtServer();
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisible();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
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
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	CheckChartsOfAccounts(Cancel);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure
#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PostingDateFromDocumentOnChange(Item)
	
	Object.PostingDateFromDocument = Boolean(PostingDateFromDocument);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure TransformationMethodOnChange(Item)
	
	SetVisible();
	
EndProcedure

&AtClient
Procedure OriginalDocumentOnChange(Item)
	
	SetVisible();
	
EndProcedure

&AtClient
Procedure TransformationTemplateOnChange(Item)
	
	If ValueIsFilled(Object.TransformationMethod) Then
		FillByTemplate();
	EndIf;
	
	SetVisible();
	
EndProcedure

&AtClient
Procedure ChartOfAccountsSourceOnChange(Item)
	
	ChartOfAccountsSourceBeforeChange = ChartOfAccountsSource;
	ChartOfAccountsSource = Object.ChartOfAccountsSource;
	
	If ChartOfAccountsSourceBeforeChange <> Object.ChartOfAccountsSource Then
		
		FillAccountingRegisterSource();
		
		For Each PostingsRow In Object.Postings Do
			
			PostingsRow.DebitSource = Undefined;
			PostingsRow.CreditSource = Undefined;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChartOfAccountsOnChange(Item)
	
	ChartOfAccountsBeforeChange = ChartOfAccounts;
	ChartOfAccounts = Object.ChartOfAccounts;
	
	If ChartOfAccountsBeforeChange <> Object.ChartOfAccounts Then
		
		FillAccountingRegister();
		
		For Each PostingsRow In Object.Postings Do
			
			PostingsRow.Debit = Undefined;
			PostingsRow.Credit = Undefined;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure PostingsDebitStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenChartOfAccountsChoiceForm(Object.ChartOfAccounts, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PostingsDebitSourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenChartOfAccountsChoiceForm(Object.ChartOfAccountsSource, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PostingsCreditStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenChartOfAccountsChoiceForm(Object.ChartOfAccounts, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PostingsCreditSourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenChartOfAccountsChoiceForm(Object.ChartOfAccountsSource, Item, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillDocument(Command)
	
	FillDocumentAtServer();
	
EndProcedure

&AtClient
Procedure SetPeriod(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.StartDate;
	Dialog.Period.EndDate	= Object.EndDate;
	
	NotifyDescription = New NotifyDescription("SetPeriodCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetPeriodCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		Object.StartDate	= Result.StartDate;
		Object.EndDate		= Result.EndDate;
		
	EndIf;
	
EndProcedure

#Endregion

#Region Private

&AtClient
Procedure SetVisible()
	
	OrigDocVisible = (Object.TransformationMethod = PredefinedValue("Enum.TransformationMethods.ByDocumentsOnPosting")
		OR Object.TransformationMethod = PredefinedValue("Enum.TransformationMethods.ByDocumentsManual"));
	
	Items.OriginalDocument.Visible = OrigDocVisible;
	
	Items.PostingPage.ReadOnly = ValueIsFilled(Object.OriginalDocument);
	
EndProcedure

&AtServer
Procedure FillByTemplate()
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.FillByTransformationTemplate();
	ValueToFormAttribute(DocumentObject,"Object");
	
EndProcedure

&AtServer
Procedure FillDocumentAtServer()
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.FillDocumentPostings();
	ValueToFormAttribute(DocumentObject,"Object");
	
EndProcedure

&AtServer
Procedure FillChartsOfAccountsList()
	
	FinancialAccounting.FillChartOfAccountsList(Items.ChartOfAccounts.ChoiceList);
	FinancialAccounting.FillChartOfAccountsList(Items.ChartOfAccountsSource.ChoiceList);
	
EndProcedure

&AtServer
Procedure FillAccountingRegister()
	
	Object.AccountingRegister = FinancialAccounting.GetAccountinRegisterByChartOfAccounts(Object.ChartOfAccounts);
	
EndProcedure

&AtServer
Procedure FillAccountingRegisterSource()
	
	Object.AccountingRegisterSource = FinancialAccounting.GetAccountinRegisterByChartOfAccounts(Object.ChartOfAccountsSource);
	
EndProcedure

&AtServerNoContext
Function ObjectAttributesValues(Ref, Attributes);
	
	Return Common.ObjectAttributesValues(Ref, Attributes);
	
EndFunction

&AtClient
Procedure OpenChartOfAccountsChoiceForm(ChartOfAccounts, Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(ChartOfAccounts) Then
		
		AttributesStructure = ObjectAttributesValues(ChartOfAccounts, "FullName");
		
		OpenForm(AttributesStructure.FullName + ".ChoiceForm", , Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckChartsOfAccounts(Cancel)
	
	If NOT ValueIsFilled(Object.ChartOfAccounts) Then
		CommonClientServer.MessageToUser(NStr("en = 'You should choose a chart of accounts'; ru = 'Необходимо выбрать план счетов';pl = 'Możesz wybrać plan kont';es_ES = 'Debe elegir un plan de cuentas';es_CO = 'Debe elegir un plan de cuentas';tr = 'Hesap planı seçmelisiniz';it = 'Dovete scegliere un piano dei conti';de = 'Sie sollten eine Kontenplan auswählen'"),
			,
			"ChartOfAccounts",
			,
			Cancel);
	EndIf;
	
	If NOT ValueIsFilled(Object.ChartOfAccountsSource) Then
		CommonClientServer.MessageToUser(NStr("en = 'You should choose a source chart of accounts'; ru = 'Необходимо выбрать исходный план счетов';pl = 'Możesz wybrać źródło planu kont';es_ES = 'Debe elegir un plan de cuentas de fuente';es_CO = 'Debe elegir un plan de cuentas de fuente';tr = 'Kaynak hesap planı seçmelisiniz';it = 'Dovete scegliere una fonte di piano dei conti';de = 'Sie sollten einen Ursprungskontenplan wählen'"),
			,
			"ChartOfAccountsSource",
			,
			Cancel);
	EndIf;
	
	If NOT Cancel AND Object.ChartOfAccounts = Object.ChartOfAccountsSource Then
		CommonClientServer.MessageToUser(NStr("en = 'Charts of accounts should be different'; ru = 'Планы счетов не должны совпадать';pl = 'Plany kont muszą być różne';es_ES = 'Los planes de cuentas deben ser diferentes';es_CO = 'Los planes de cuentas deben ser diferentes';tr = 'Hesap planları farklı olmalıdır';it = 'I piani dei conti devono essere diversi';de = 'Kontenplan sollte sich unterscheiden'"), , , , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	
	Object.StartDate = BegOfMonth(?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	Object.EndDate = EndOfMonth(?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	
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