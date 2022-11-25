
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	// Initial group setup.
	DataGroup = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup.UserSettingID = "MainGrouping";
	DataGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("Recipient");
	DataGroupItem.Use = True;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("Sender");
	DataGroupItem.Use = False;
	
	// Conditional group setup.
	GroupOption = "ByRecipient";
	SetListGroup();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GroupOptionOnChange(Item)
	
	SetListGroup();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SendAndReceiveMessages(Command)
	
	MessagesExchangeClient.SendAndReceiveMessages();
	
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Setting(Command)
	
	OpenForm("CommonForm.MessagesExchangeSetup",, ThisObject);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentData <> Undefined Then
		
		If Items.List.CurrentData.Property("RowGroup")
			AND TypeOf(Items.List.CurrentData.RowGroup) = Type("DynamicListGroupRow") Then
			
			ShowMessageBox(, NStr("ru = 'Действие недоступно для строки группировки списка.'; en = 'The action cannot be performed for a list group row.'; pl = 'Ta czynność nie jest dostępna dla wiersza grupowania listy.';es_ES = 'La acción no está disponible para la fila de agrupación de listas.';es_CO = 'La acción no está disponible para la fila de agrupación de listas.';tr = 'Eylem, liste gruplama satırı için mevcut değildir.';it = 'L''azione non può essere eseguita per un elenco gruppo riga.';de = 'Die Aktion ist für die Listengruppierungszeile nicht verfügbar.'"));
			
		Else
			
			If Items.List.SelectedRows.Count() > 1 Then
				
				QuestionRow = NStr("ru = 'Удалить выделенные сообщения?'; en = 'Do you want to delete selected messages?'; pl = 'Usunąć wybrane wiadomości?';es_ES = '¿Borrar los mensajes seleccionados?';es_CO = '¿Borrar los mensajes seleccionados?';tr = 'Seçilmiş mesajlar silinsin mi?';it = 'Volete eliminare i messaggi selezionato?';de = 'Löschen Sie die ausgewählten Nachrichten?'");
				
			Else
				
				QuestionRow = NStr("ru = 'Удалить сообщение ""[Message]""?'; en = 'Do you want to delete the [Message] message?'; pl = 'Czy chcesz usunąć [Message] wiadomość?';es_ES = '¿Borrar el mensaje [Message]?';es_CO = '¿Borrar el mensaje [Message]?';tr = '""[Message]"" mesaj silinsin mi?';it = 'Volete eliminare il messaggio [Message]?';de = 'Nachricht löschen ""[Message]""?'");
				QuestionRow = StrReplace(QuestionRow, "[Message]", Items.List.CurrentData.Description);
				
			EndIf;
			
			NotifyDescription = New NotifyDescription("DeleteCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, QuestionRow, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		DeleteMessageDirectly(Items.List.SelectedRows);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListGroup()
	
	RecipientGroup  = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[0];
	SenderGroup = List.SettingsComposer.Settings.Structure[0].GroupFields.Items[1];
	
	If GroupOption = "NoGroup" Then
		
		RecipientGroup.Use = False;
		SenderGroup.Use = False;
		
		Items.Sender.Visible = True;
		Items.Recipient.Visible = True;
		
	Else
		
		Usage = (GroupOption = "ByRecipient");
		
		RecipientGroup.Use = Usage;
		SenderGroup.Use = Not Usage;
		
		Items.Sender.Visible = Usage;
		Items.Recipient.Visible = Not Usage;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteMessageDirectly(Val Messages)
	
	For Each Message In Messages Do
		
		If TypeOf(Message) <> Type("CatalogRef.DataAreaMessages") Then
			Continue;
		EndIf;
		
		MessageObject = Message.GetObject();
		
		If MessageObject <> Undefined Then
			
			MessageObject.Lock();
			
			If ValueIsFilled(MessageObject.Sender)
				AND MessageObject.Sender <> MessageExchangeInternal.ThisNode() Then
				
				MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
				MessageObject.DataExchange.Recipients.AutoFill = False;
				
			EndIf;
			
			MessageObject.DataExchange.Load = True; // Presence of catalog references must not prevent or slow down deletion of catalog items.
			MessageObject.Delete();
			
		EndIf;
		
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Locked record appearance.
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Locked");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);
	
	// Quick message appearance.
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsInstantMessage");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Locked");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SuccessResultColor);
	
EndProcedure

#EndRegion
