
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
		
	If Not Parameters.Property("SelectedElements")  
	   Or TypeOf(Parameters.SelectedElements) <> Type("Array")
	   Or Parameters.SelectedElements.Count() = 0 Then
		
		ErrorDescription = NStr("en = 'No elements for status changing.'; ru = 'Нет элементов для изменения статуса.';pl = 'Brak elementów do zmiany statusu.';es_ES = 'No hay elementos para cambiar el estado.';es_CO = 'No hay elementos para cambiar el estado.';tr = 'Durum değişikliği için öğe yok.';it = 'Non vi sono elementi per modificare lo stato.';de = 'Keine Elemente für Ändern des Status.'");
		CommonClientServer.MessageToUser(ErrorDescription, , , , Cancel);
		
	EndIf;
	
	Parameters.Property("Operation", Operation);
	Parameters.Property("Company", Company);
	
	InitTemplatesTable(Parameters.SelectedElements);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagement();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AccountsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.Accounts.CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	ShowValue( , CurrentRow.AccountRef);
	
EndProcedure

&AtClient
Procedure PeriodSelection(Command)
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = New StandardPeriod(StartDate, EndDate);
	
	PeriodSelectionEnding = New NotifyDescription("PeriodSelectionEnding", ThisObject);
	Dialog.Show(PeriodSelectionEnding);
	
EndProcedure

&AtClient
Procedure PeriodSelectionEnding(Value, AddParameters) Export

	If TypeOf(Value) = Type("StandardPeriod") Then
		StartDate	= Value.StartDate;
		EndDate		= Value.EndDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueCommand(Command)
	
	ClearMessages();
	Cancel = False;
	
	If CompanyIsMandatory And Not ValueIsFilled(Company) Then
		
		ErrorText = NStr("en = 'Cannot add company to accounts. ""Company"" is required';ru = 'Не удалось добавить организацию в счета. Укажите организацию';pl = 'Nie można dodać firmy do kont. ""Firma"" jest wymagana';es_ES = 'No se puede añadir la empresa a las cuentas. Se requiere la ""empresa"".';es_CO = 'No se puede añadir la empresa a las cuentas. Se requiere la ""empresa"".';tr = 'Hesaplara iş yeri eklenemiyor. ""İş yeri"" gerekli';it = 'Impossibile aggiungere l''azienda ai conti. ""Azienda"" è richiesto';de = 'Fehler beim Hinzufügen der Firma zu Konten. ""Firma"" ist erforderlich'");
		CommonClientServer.MessageToUser(ErrorText, , "Company");
		Cancel = True;
		
	EndIf;
	
	If ValueIsFilled(EndDate) And EndDate < StartDate Then
		
		ErrorText = NStr("en = 'Cannot add company to accounts. ""Active from"" date must be less or equal to ""Active till"" date.';ru = 'Не удалось добавить организацию в счета. Дата в поле ""Активен с"" не может превышать дату в поле ""Активен до"".';pl = 'Nie można dodać firmy do kont. Data ""Aktywny od"" powinna być mniejsza lub równa dacie ""Aktywny do"".';es_ES = 'No se puede añadir la empresa a las cuentas. La fecha ""Activo desde"" debe ser menor o igual a la fecha ""Activo hasta"".';es_CO = 'No se puede añadir la empresa a las cuentas. La fecha ""Activo desde"" debe ser menor o igual a la fecha ""Activo hasta"".';tr = 'Hesaplara iş yeri eklenemiyor. ""Aktivasyon başlangıcı"" tarihi ""Aktivasyon bitişi"" tarihinden önce veya aynı olmalıdır.';it = 'Impossibile aggiungere l''azienda ai conti. La data ""Attivo da"" deve essere precedente o uguale alla data ""Attivo fino"".';de = 'Fehler beim Hinzufügen der Firma zu Konten. Das Datum ""Aktiv vom"" muss vor oder gleich dem Datum ""Aktiv bis"" liegen.'");
		CommonClientServer.MessageToUser(ErrorText, , "StartDate");
		Cancel = True;
		
	EndIf;
	
	If Cancel = True Then
		Return;
	EndIf;
	
	Items.Header.Enabled = False;
	
	LongTermOperation = ExecuteInBackgroundServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	
	ExecuteInBackgroundEnding = New NotifyDescription("ExecuteInBackgroundEnding", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(LongTermOperation, ExecuteInBackgroundEnding, IdleParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()

	If Operation = "ChangeAccountPeriod" Then
		
		ThisObject.Title = NStr("en = 'Change account validity period'; ru = 'Изменить срок действия счета';pl = 'Zmień okres ważności konta';es_ES = 'Cambiar el periodo de validez de la cuenta';es_CO = 'Cambiar el periodo de validez de la cuenta';tr = 'Hesap geçerlilik dönemini değiştir';it = 'Modificare il periodo di validità del conto';de = 'Gültigkeitsdauer des Kontos ändern'");
		CompanyIsMandatory = False;
		
	ElsIf Operation = "AddCompany" Then
		
		ThisObject.Title = NStr("en = 'Apply account to company'; ru = 'Применить счет к организации';pl = 'Zastosuj konto do firmy';es_ES = 'Aplicar la cuenta a la empresa';es_CO = 'Aplicar la cuenta a la empresa';tr = 'Hesabı iş yerine uygula';it = 'Applicare conto all''azienda';de = 'Konto für Firma verwenden'");
		CompanyIsMandatory = True;
		
	ElsIf Operation = "ChangeCompanyPeriod" Then
		
		ThisObject.Title = NStr("en = 'Change account validity period for company'; ru = 'Изменить срок действия счета для организации';pl = 'Zmień okres ważności konta dla firmy';es_ES = 'Cambiar el periodo de validez de la cuenta para la empresa';es_CO = 'Cambiar el periodo de validez de la cuenta para la empresa';tr = 'İş yeri için hesap geçerlilik dönemini değiştir';it = 'Modificare il periodo di validità del conto per l''azienda';de = 'Gültigkeitsdauer des Kontos für Firma ändern'");
		CompanyIsMandatory = True;
		Items.Company.ReadOnly = True;
		
	EndIf;
	
	Items.Company.Visible = CompanyIsMandatory;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// First one
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Accounts.Error");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	WorkWithForm.AddDataCompositionAppearanceField(Item, "Accounts"); 
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.AccentColor);
	
	// Second one
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Accounts.Error");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.NegativeTextColor);

	WorkWithForm.AddDataCompositionAppearanceField(Item, "Accounts"); 

EndProcedure

&AtServer
Procedure InitTemplatesTable(SelectedElements)
	
	For Each Row In SelectedElements Do
		
		ChildArray = ChartsOfAccounts.MasterChartOfAccounts.GetChildAccountsArray(Row);
		CommonClientServer.SupplementArray(SelectedElements, ChildArray, True);
		
	EndDo;
		
	Index = 1;
	For Each Row In SelectedElements Do
		
		NewRow = Accounts.Add();
		NewRow.LineNumber	= Index;
		NewRow.AccountRef	= Row;
		NewRow.Error		= - 1;
		
		Index = Index + 1;
		
	EndDo;
	
	Accounts.Sort("AccountRef");

EndProcedure

#Region ExecuteInBackground

&AtServer
Function ExecuteInBackgroundServer()
	
	ParametersStructureBackgroundJob	= New Structure();
	UpdateParameters					= New Structure();
	BackgroundJobProcedure				= "ChartsOfAccounts.MasterChartOfAccounts.AddInformationWithCheck";
	JobDescription						= NStr("en = 'Accounts update process...';ru = 'Идет обновление счетов...';pl = 'Trwa aktualizacja kont...';es_ES = 'Proceso de actualización de cuentas...';es_CO = 'Proceso de actualización de cuentas...';tr = 'Hesap güncelleme süreci...';it = 'Processo di aggiornamento dei conti...';de = 'Aktualisieren von Konten läuft...'");
	
	UpdateParameters.Insert("Operation"	, Operation);
	UpdateParameters.Insert("Company"	, Company);
	UpdateParameters.Insert("StartDate"	, StartDate);
	UpdateParameters.Insert("EndDate"	, EndDate);
	
	ParametersStructureBackgroundJob.Insert("AccountsTable"			, Accounts.Unload());
	ParametersStructureBackgroundJob.Insert("NewAccountParameters"	, UpdateParameters);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(BackgroundJobProcedure, ParametersStructureBackgroundJob, ExecutionParameters);
	
EndFunction

&AtClient
Procedure ExecuteInBackgroundEnding(Result, AdditionalParameters) Export

	Items.Header.Enabled = True;
	
	If Result = Undefined Then
		Return;
	ElsIf Result.Status = "Error" Then
		CommonClientServer.MessageToUser(Result.DetailedErrorPresentation);
	ElsIf Result.Status = "Completed" Then
		ProcessResult(Result.ResultAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessResult(ResultAddress)
	
	ProcessResultServer(ResultAddress);
	
	SuccessStr		= New Structure("Error", 0);
	SuccessCount	= Accounts.FindRows(SuccessStr).Count();
	ErrorCount		= Accounts.Count() - SuccessCount;
	
	TitleTmplt = NStr("en = '%1 accounts'; ru = 'счета %1';pl = '%1 kont';es_ES = '%1 cuentas';es_CO = '%1 cuentas';tr = '%1 hesap';it = '%1 conti';de = '%1 Konten'");
	
	Items.GroupSuccessesErrors.Visible = True;
	
	Items.SuccessCount.Title	= StrTemplate(TitleTmplt, SuccessCount);
	Items.ErrorCount.Title		= StrTemplate(TitleTmplt, ErrorCount);
	
	If ErrorCount = 0 Then
		Items.FormContinueCommand.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessResultServer(ResultAddress)
	
	ResultStructure = GetFromTempStorage(ResultAddress);
	AccountsTable = ResultStructure.AccountsTable;

	Accounts.Load(AccountsTable);
	
	For Each Message In ResultStructure.Messages Do
		Message.Message();
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion