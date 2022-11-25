
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	Items.GroupSuccessesErrors.Visible = False;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	NewStatus = Undefined;
	Parameters.Property("Status",	NewStatus);
	Parameters.Property("DateFrom", DateFrom);
	
	If Not ValueIsFilled(DateFrom) Then
		DateFrom = CurrentSessionDate();
	EndIf;
	
	If NewStatus = "Active" Then
		
		Status = Enums.AccountingEntriesTemplatesStatuses.Active;
		DateIsMandatory = True;
		
		Items.DateTo.Visible = True;
		Items.PeriodSelection.Visible = True;
		
	ElsIf NewStatus = "Draft" Then		
		Status = Enums.AccountingEntriesTemplatesStatuses.Draft;
		DateIsMandatory = False;
		DateFrom = Undefined;
		DateTo   = Undefined;
	Else		
		ErrorDescription = NStr("en = 'Incorrect command!'; ru = 'Неверная команда!';pl = 'Nieprawidłowe polecenie!';es_ES = '¡Comando incorrecto!';es_CO = '¡Comando incorrecto!';tr = 'Yanlış komut!';it = 'Comando errato!';de = 'Falscher Befehl!'");
		CommonClientServer.MessageToUser(ErrorDescription, , , , Cancel);
	EndIf;
	
	If Not Parameters.Property("SelectedElements")
		Or TypeOf(Parameters.SelectedElements) <> Type("Array")
		Or Parameters.SelectedElements.Count() = 0 Then
		
		ErrorDescription = NStr("en = 'No elements for status changing.'; ru = 'Нет элементов для изменения статуса.';pl = 'Brak elementów do zmiany statusu.';es_ES = 'No hay elementos para cambiar el estado.';es_CO = 'No hay elementos para cambiar el estado.';tr = 'Durum değişikliği için öğe yok.';it = 'Non vi sono elementi per modificare lo stato.';de = 'Keine Elemente für Ändern des Status.'");
		CommonClientServer.MessageToUser(ErrorDescription, , , , Cancel);
		
	EndIf;
	
	InitTemplatesTable(Parameters.SelectedElements);
	Items.DateFrom.Visible = DateIsMandatory;

EndProcedure

&AtClient
Procedure TemplatesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CuurentRow = Items.Templates.CurrentData;
	
	If CuurentRow = Undefined Then
		Return;
	EndIf;
	
	ShowValue( , CuurentRow.TemplateRef);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ContinueCommand(Command)
	
	ClearMessages();
	
	If DateIsMandatory And Not ValueIsFilled(DateFrom) Then
		
		ErrorText = NStr("en = 'Cannot set the %1 status. ""From"" date is required.';ru = 'Не удалось установить статус ""%1"". Укажите дату в поле ""С"".';pl = 'Nie można ustawić statusu %1. Data ""Od"" jest wymagana.';es_ES = 'No se puede establecer el %1 estado. Se requiere la fecha ""Desde"".';es_CO = 'No se puede establecer el %1 estado. Se requiere la fecha ""Desde"".';tr = '%1 durumu ayarlanamıyor. ""Başlangıç"" tarihi gerekli.';it = 'Impossibile impostare lo stato %1. La data ""Da"" è richiesta.';de = 'Fehler beim Festlegen des Status %1. Das Datum ""Vom"" ist ein Pflichtfeld.'");
		
		CommonClientServer.MessageToUser(StrTemplate(ErrorText, Status), , "DateFrom");
		
		Return;
		
	EndIf;
	If ValueIsFilled(DateFrom) And ValueIsFilled(DateTo) And DateTo < DateFrom Then
		
		ErrorMessage = NStr("en = '""To"" date must be equal to or later than ""From"" date. Edit ""To"" date, then try again.'; ru = 'Дата в поле ""По"" не может быть меньше даты в поле ""С"". Отредактируйте дату в поле ""По"" и повторите попытку.';pl = 'Data ""Do"" powinna być równa lub późniejsza niż data ""Od"". Edytuj datę ""Do"", następnie spróbuj ponownie.';es_ES = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';es_CO = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';tr = '""Bitiş"" tarihi ""Başlangıç"" tarihi ile aynı veya daha sonra olmalıdır. ""Bitiş"" tarihini değiştirip tekrar deneyin.';it = 'La data ""fino a"" deve essere uguale o successiva alla data ""Da"". Modificare la data ""fino a"", poi riprovare.';de = '""Bis zu"" muss gleich oder später als Datum ""Von "" liegen. Bearbeiten Sie das Datum ""Bis zum"", dann versuchen Sie erneut.'");
		
		CommonClientServer.MessageToUser(ErrorMessage, , "DateTo");
		
		Return;
		
	EndIf;
	
	Items.GroupPeriod.Enabled = False;
	
	LongTermOperation = ExecuteInBackgroundServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	
	ExecuteInBackgroundEnding = New NotifyDescription("ExecuteInBackgroundEnding", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(LongTermOperation, ExecuteInBackgroundEnding, IdleParameters); 
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitTemplatesTable(SelectedElements)
	
	Index = 1;
	For Each Row In SelectedElements Do
		
		NewRow = Templates.Add();
		NewRow.LineNumber	= Index;
		NewRow.TemplateRef	= Row;
		NewRow.TemplateCode = Common.ObjectAttributeValue(Row, "Code");
		NewRow.Error		= - 1;
		
		Index = Index + 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
		
	ConditionalAppearance.Items.Clear();
	
	// First one
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Templates.Error");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	WorkWithForm.AddDataCompositionAppearanceField(Item, "Templates");
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.AccentColor);
	
	// Second one
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Templates.Error");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.NegativeTextColor);

	WorkWithForm.AddDataCompositionAppearanceField(Item, "Templates");

EndProcedure

&AtServer
Function ExecuteInBackgroundServer()
	
	ParametersStructureBackgroundJob	= New Structure();
	NewTemplateParameters				= New Structure();
	BackgroundJobProcedure				= "Catalogs.AccountingEntriesTemplates.ChangeStatusWithCheck";
	JobDescription						= NStr("en = 'Statuses  changing process...';ru = 'Идет изменение статусов...';pl = 'Trwa zmiana statusów...';es_ES = 'Proceso de cambio de estado...';es_CO = 'Proceso de cambio de estado...';tr = 'Durum değiştirme süreci...';it = 'Processo modifica stati...';de = 'Status werden geändert...'");
	
	NewTemplateParameters.Insert("Status"   , Status);
	NewTemplateParameters.Insert("StartDate", DateFrom);
	NewTemplateParameters.Insert("EndDate"  , DateTo);
	
	ParametersStructureBackgroundJob.Insert("TemplatesTable"		, Templates.Unload());	
	ParametersStructureBackgroundJob.Insert("NewTemplateParameters" , NewTemplateParameters);	
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(BackgroundJobProcedure, ParametersStructureBackgroundJob, ExecutionParameters);
	
EndFunction

&AtClient
Procedure ExecuteInBackgroundEnding(Result, AdditionalParameters) Export
	
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
	SuccessCount	= Templates.FindRows(SuccessStr).Count();
	ErrorCount		= Templates.Count() - SuccessCount;
	
	TitleTmplt = NStr("en = '%1 templates'; ru = 'шаблоны %1';pl = '%1 szablonów';es_ES = '%1 plantillas';es_CO = '%1 plantillas';tr = '%1 şablon';it = '%1 modelli';de = '%1 Vorlagen'");
	
	Items.GroupSuccessesErrors.Visible = True;
	
	Items.SuccessCount.Title	= StrTemplate(TitleTmplt, SuccessCount);
	Items.ErrorCount.Title		= StrTemplate(TitleTmplt, ErrorCount);
	
	If ErrorCount = 0 Then
		Items.FormContinue.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessResultServer(ResultAddress)
	
	ResultStructure = GetFromTempStorage(ResultAddress);
	TemplatesTable  = ResultStructure.TemplatesTable;	
	
	Templates.Load(TemplatesTable);
	
	For Each TemplateLine In Templates Do
		
		Version = Common.ObjectAttributeValue(TemplateLine.TemplateRef, "DataVersion");
		
		If Version <> TemplateLine.TemplateRef.DataVersion Then
			
			TemplateObject = TemplateLine.TemplateRef.GetObject();
			While Version <> TemplateLine.TemplateRef.DataVersion Do
				TemplateObject.Read();
				Version = Common.ObjectAttributeValue(TemplateLine.TemplateRef, "DataVersion");
			EndDo;
			
		EndIf;
		
	EndDo;
	
	For Each Message In ResultStructure.Messages Do
		Message.Message();
	EndDo;
	
EndProcedure

&AtClient
Procedure PeriodSelection(Command)
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = New StandardPeriod(DateFrom, DateTo);
	
	PeriodSelectionEnding = New NotifyDescription("PeriodSelectionEnding", ThisObject);
	Dialog.Show(PeriodSelectionEnding);
	
EndProcedure

&AtClient
Procedure PeriodSelectionEnding(Value, AddParameters) Export

	If TypeOf(Value) = Type("StandardPeriod") Then
		DateFrom = Value.StartDate;
		DateTo   = Value.EndDate;		
	EndIf;
	
EndProcedure

#EndRegion
