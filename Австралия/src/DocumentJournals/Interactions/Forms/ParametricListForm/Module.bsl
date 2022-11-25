///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Variables

&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	Interactions.InitializeInteractionsListForm(ThisObject, Parameters);
	Items.CreateEmailSpecialButtonTreeList.Visible = EmailOnly;
	Items.CreateTreeGroup.Visible = NOT EmailOnly;
	If EmailOnly Then
		TitleParticipantsMail =  NStr("ru = 'Кому, от'; en = 'To, from'; pl = 'Do, od';es_ES = 'Para, de';es_CO = 'Para, de';tr = 'Kime, kimden';it = 'A, da';de = 'An, von'");
		Items.InteractionsTreeParticipants.Title = TitleParticipantsMail;
		Items.Members.Title = TitleParticipantsMail;
	EndIf;
	
	
	
	If Parameters.Property("Filter") Then
		
		CaptionPattern = NStr("ru = 'Взаимодействия по %1'; en = '%1 interactions'; pl = '%1 interakcji';es_ES = '%1 interacciones';es_CO = '%1 interacciones';tr = '%1 etkileşim';it = '%1 interazioni';de = '%1 Interaktionen'");
		
		If Parameters.Filter.Property("Topic") Then
			
			If Parameters.Property("AdditionalParameters")
				AND Parameters.AdditionalParameters.Property("InteractionType") Then
				
				If Parameters.AdditionalParameters.InteractionType = "Interaction" Then
					SubjectForFilter = Interactions.GetSubjectValue(Parameters.Filter.Topic);
					Parameters.Filter.Topic = SubjectForFilter ;
				ElsIf Parameters.AdditionalParameters.InteractionType = "Topic" Then
					SubjectForFilter = Parameters.Filter.Topic;
				EndIf;
			EndIf;
			
			Parameters.Filter.Delete("Topic");
			SetFilterBySubject();
			
			Title = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, Common.SubjectString(SubjectForFilter));
			
		ElsIf Parameters.Filter.Property("Contact") Then
			
			Contact = Parameters.Filter.Contact;
			Title = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, Common.SubjectString(Contact));
			Parameters.Filter.Delete("Contact");
			SetFilterByContact();
			
		EndIf;
	EndIf;
	
	Interactions.FillListOfDocumentsAvailableForCreation(DocumentsAvailableForCreation);
	Interactions.FillSubmenuByInteractionType(Items.TreeInteractionType, ThisObject);
	Interactions.FillSubmenuByInteractionType(Items.InteractionTypeList, ThisObject);
	
	InteractionType = ?(EmailOnly,"AllMessages","All");
	Status = "All";
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Status = Settings.Get("Status");
	If Status <> Undefined Then
		Settings.Delete("Status");
	EndIf;
	If Not UseReviewedFlag Or NOT ValueIsFilled(Status) Then
		Status = "All";
	EndIf;
	EmployeeResponsible = Settings.Get("EmployeeResponsible");
	If EmployeeResponsible <> Undefined Then
		Settings.Delete("EmployeeResponsible");
	EndIf;
	InTreeStructure = Settings.Get("InTreeStructure");
	If InTreeStructure <> Undefined Then
		Settings.Delete("InTreeStructure");
	EndIf;
	
	Interactions.OnImportInteractionsTypeFromSettings(ThisObject, Settings);
	
	PagesManagementServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If InteractionsClientServer.IsInteraction(Source) Then
		If Items.TreeListPages.CurrentPage = Items.TreePage Then
			FillInteractionsTreeClient();
		Else
			If FilterBySubject Then
				SetFilterBySubject();
			Else
				SetFilterByContact();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Users.Form.ListForm") Then
		
		If SelectedValue <> Undefined Then
			
			ArrayOfChangedDocuments = New Array;
			Replaced = False;
			SetEmployeeResponsible(SelectedValue, ArrayOfChangedDocuments);
			
			If Items.TreeListPages.CurrentPage = Items.ListPage Then
				If ArrayOfChangedDocuments.Count() > 0 Then
					Items.List.Refresh();
				EndIf;
			Else
				If ArrayOfChangedDocuments.Count() > 0  Then
					ExpandAllTreeRows();
				EndIf;
			EndIf;
			
			For Each ChangedDocument In ArrayOfChangedDocuments Do
				
				Notify("WriteInteraction", ChangedDocument);
				
			EndDo;
			
		EndIf;
		
	ElsIf ChoiceContext = "SubjectExecuteSubjectType" Then
		
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectExecute";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(SelectedValue + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectExecute" Then
		
		If SelectedValue <> Undefined Then
			
			If FilterBySubject AND SubjectForFilter = SelectedValue Then
				Return;
			EndIf;
			
			Replaced = False;
			SetSubject(SelectedValue, Replaced);
			
			If Items.TreeListPages.CurrentPage = Items.ListPage Then
				If Replaced Then
					Items.List.Refresh();
				EndIf;
			Else
				If Replaced Then
					ExpandAllTreeRows();
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EmployeeResponsibleOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		InteractionsClientServer.QuickFilterListOnChange(ThisObject, Item.Name,, FilterBySubject);
		
	Else
		
		FillInteractionsTreeClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		DateForFilter = CommonClient.SessionDate();
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,Item.Name, DateForFilter, FilterBySubject);
		
	Else
		
		FillInteractionsTreeClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	FillingValues = New Structure("Topic,Contact",SubjectForFilter,Contact);
	
	InteractionsClient.ListBeforeAddRow(
		Item,Cancel,Clone,EmailOnly,DocumentsAvailableForCreation,
		New Structure("FillingValues", FillingValues));
	
EndProcedure 

&AtClient
Procedure InteractionsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		StandardProcessing = False;
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionsTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	If Items.InteractionsTree.SelectedRows.Count() > 0 Then
		
		HasItemsMarkedForDeletion = False;
		For each SelectedRow In Items.InteractionsTree.SelectedRows Do
			If Items.InteractionsTree.RowData(SelectedRow).DeletionMark Then
				HasItemsMarkedForDeletion = True;
				Break;
			EndIf;
		EndDo;
		
		If HasItemsMarkedForDeletion Then
			QuestionText = NStr("ru = 'Снять с выделенных элементов пометку на удаление?'; en = 'Clear marks for deletion of the selected items?'; pl = 'Wyczyścić zaznaczenia do usunięcia wybranych elementów?';es_ES = '¿Quitar las marcas para borrar los elementos seleccionados?';es_CO = '¿Quitar las marcas para borrar los elementos seleccionados?';tr = 'Seçili öğelerin silme işareti kaldırılsın mı?';it = 'Deselezionare per la cancellazione gli elementi selezionati?';de = 'Löschmarkierungen der ausgewählten Elemente deaktivieren?'");
		Else
			QuestionText = NStr("ru = 'Пометить выделенные строки на удаление?'; en = 'Mark the selected lines for deletion?'; pl = 'Zaznaczyć wybrane wiersze do usunięcia?';es_ES = '¿Marcar las líneas seleccionadas para borrarlas?';es_CO = '¿Marcar las líneas seleccionadas para borrarlas?';tr = 'Seçili satırlar silinmek üzere işaretlensin mi?';it = 'Contrassegnare le righe selezionate per la cancellazione?';de = 'Markieren die ausgewählten Zeilen zum Löschen?'");
		EndIf;
		
		AdditionalParameters = New Structure("HasItemsMarkedForDeletion", HasItemsMarkedForDeletion);
		OnCloseNotifyHandler = New NotifyDescription("QuestionOnMarkForDeletionAfterCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(OnCloseNotifyHandler,
		               QuestionText,QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure InteractionsTreeBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionsTreeBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	Cancel = True;
	If Clone Then
		CurrentData = Item.CurrentData;
		If CurrentData <> Undefined Then
			If TypeOf(CurrentData.Ref) = Type("DocumentRef.IncomingEmail") 
				OR TypeOf(CurrentData.Ref) = Type("DocumentRef.OutgoingEmail") Then
				
				ShowMessageBox(, NStr("ru = 'Копирование электронных писем запрещено.'; en = 'Email copying is not allowed.'; pl = 'Kopiowanie wiadomości e-mail jest zabronione.';es_ES = 'No está permitido copiar el correo electrónico.';es_CO = 'No está permitido copiar el correo electrónico.';tr = 'E-posta kopyalamaya izin verilmiyor.';it = 'Non è permesso copiare le email.';de = 'Kopieren von E-Mails ist nicht gestattet.'"));
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.Meeting") Then
				
				OpenForm("Document.Meeting.ObjectForm",
					New Structure("CopyingValue", CurrentData.Ref), ThisObject);
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.PlannedInteraction") Then
				
				OpenForm("Document.PlannedInteraction.ObjectForm",
					New Structure("CopyingValue", CurrentData.Ref), ThisObject);
				
			ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.PhoneCall") Then
				
				OpenForm("Document.PhoneCall.ObjectForm", 
					New Structure("CopyingValue",CurrentData.Ref), ThisObject);
				
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionTypeOnChange(Item)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	Else
		FillInteractionsTreeClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure InteractionTypeStatusClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Attachable_ChangeFilterInteractionType(Command)

	ChangeFilterInteractionTypeServer(Command.Name);
	If Items.TreeListPages.CurrentPage <> Items.ListPage Then
		FillInteractionsTreeClient();
	EndIf;

EndProcedure

&AtClient
Procedure ReviewedExecute(Command)
	
	If NOT CorrectChoice() Then
		Return;
	EndIf;
	
	ReviewedFlag = (Not Command.Name = "NotReviewed");
	
	Replaced = False;
	InteractionsArray = New Array;
	SetReviewedFlag(Replaced, ReviewedFlag, InteractionsArray);
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		If Replaced Then
			Items.List.Refresh();
		EndIf;
		
	Else
		
		If Replaced Then
			ExpandAllTreeRows();
		EndIf;
		
	EndIf;
	
	If Replaced Then
		
		For Each Interaction In InteractionsArray Do
			Notify("WriteInteraction", Interaction);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleExecute()
	
	If NOT CorrectChoice() Then
		Return;
	EndIf;
	
	ChoiceContext = Undefined;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.Users.Form.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SubjectExecute()
	
	If NOT CorrectChoice() Then
		Return;
	EndIf;
	
	ChoiceContext = "SubjectExecuteSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);
	
EndProcedure

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period = Interval;
	CloseNotificationHandler = New NotifyDescription("SelectClosingInterval", ThisObject);
	Dialog.Show(CloseNotificationHandler);
	
EndProcedure 

&AtClient
Procedure DeferReviewExecute(Command)
	
	If NOT CorrectChoice() Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	OnCloseNotifyHandler = New NotifyDescription("DateInputSubmitAfterFinished", ThisObject);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("ru = 'Отработать после'; en = 'Process after'; pl = 'Przetwórz po';es_ES = 'Procesar después';es_CO = 'Procesar después';tr = 'İşle';it = 'Processare dopo';de = 'Bearbeiten nach'"));
	
EndProcedure

&AtClient
Procedure CreateMeeting(Command)
	
	CreateNewInteraction("Meeting");
	
EndProcedure

&AtClient
Procedure CreateScheduledInteraction(Command)
	
	CreateNewInteraction("PlannedInteraction");
	
EndProcedure

&AtClient
Procedure CreatePhoneCall(Command)
	
	CreateNewInteraction("PhoneCall");
	
EndProcedure

&AtClient
Procedure CreateEmail(Command)
	
	CreateNewInteraction("OutgoingEmail");
	
EndProcedure

&AtClient
Procedure CreateNewInteraction(ObjectType)

	FillingValues = New Structure("Topic,Contact",SubjectForFilter,Contact);
	
	InteractionsClient.CreateNewInteraction(
	          ObjectType,
	          New Structure("FillingValues", FillingValues),
	          ThisObject);

EndProcedure

&AtClient
Procedure CreateSMSMessage(Command)
	
	CreateNewInteraction("SMSMessage");
	
EndProcedure

&AtClient
Procedure SwitchViewMode(Command)
	
	SwitchViewModeServer();
	
EndProcedure 

&AtClient
Procedure RefreshTree(Command)
	
	FillInteractionsTreeClient();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "InteractionsTree.Date", Items.InteractionsTreeDate.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.Date", Items.List.Name);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.List.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Reviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InteractionsTree.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("InteractionsTree.Reviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

EndProcedure

&AtServer
Procedure ChangeFilterInteractionTypeServer(CommandName)

	InteractionType = Interactions.InteractionTypeByCommandName(CommandName, EmailOnly);
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		OnChangeTypeServer();
	EndIf;

EndProcedure

&AtServer
Procedure SetReviewedFlag(Replaced, ReviewedFlag, InteractionsArray)
	
	Replaced = False;
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		GroupingType = Type("DynamicListGroupRow");
		
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				AND TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray,ReviewedFlag, Replaced);
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined AND (NOT TreeItem.Reviewed = ReviewedFlag) Then
				InteractionsArray.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray,ReviewedFlag, Replaced);
		
		If Replaced Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEmployeeResponsible(EmployeeResponsible, ArrayOfChangedDocuments)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				AND TypeOf(Interaction) <> GroupingType
				AND Interaction.EmployeeResponsible <> EmployeeResponsible Then
					Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
					ArrayOfChangedDocuments.Add(Interaction);
			EndIf;
		EndDo;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined AND TreeItem.EmployeeResponsible <> EmployeeResponsible Then
				Interactions.ReplaceEmployeeResponsibleInDocument(TreeItem.Ref, EmployeeResponsible);
				
				ArrayOfChangedDocuments.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		If ArrayOfChangedDocuments.Count() > 0 Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSubject(Topic,Replaced)
	
	InteractionsArray = New Array;
		
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				AND TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction)
			EndIf;
		EndDo;
		
		If InteractionsArray.Count() > 0 Then
			InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, Topic, True);
			Replaced = True;
		EndIf;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		
		For each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined AND TreeItem.Topic <> Topic Then
				InteractionsArray.Add(TreeItem.Ref);
			EndIf;
			
		EndDo;
		
		If InteractionsArray.Count() > 0 Then
			InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, Topic, True);
			Replaced = True;
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeferReview(ReviewDate, Replaced = False)
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		SelectedRows = Items.List.SelectedRows;
		InteractionsArray = New Array;
		
		GroupingType = Type("DynamicListGroupRow");
		For Each Interaction In SelectedRows Do
			If ValueIsFilled(Interaction)
				AND TypeOf(Interaction) <> GroupingType Then
					InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		InteractionsArray = Interactions.InteractionsArrayForReviewDateChange(InteractionsArray, ReviewDate);
		
		For Each Interaction In InteractionsArray Do
			
			Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
			Attributes.ReviewAfter        = ReviewDate;
			Attributes.CalculateReviewedItems = False;
			
			InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Interaction, Attributes);
			Replaced = True;
			
		EndDo;
		
	Else
		
		SelectedRows = Items.InteractionsTree.SelectedRows;
		InteractionsArray = New Array;
		
		For each Interaction In SelectedRows Do
		
			TreeItem = InteractionsTree.FindByID(Interaction);
			If TreeItem <> Undefined AND NOT TreeItem.Reviewed Then
				
				Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
				Attributes.ReviewAfter        = ReviewDate;
				Attributes.CalculateReviewedItems = False;

				InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(TreeItem.Ref, Attributes);
				Replaced = True;
				
			EndIf;
			
		EndDo;
		
		If Replaced Then
			FillInteractionsTree();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function CorrectChoice()
	
	If Items.TreeListPages.CurrentPage = Items.ListPage Then
		
		If Items.List.SelectedRows.Count() = 0 Then
			Return False;
		EndIf;
		
		For Each Item In Items.List.SelectedRows Do
			If TypeOf(Item) <> Type("DynamicListGroupRow") Then
				Return True;
			EndIf;
		EndDo;
		
		Return False;
		
	Else
		
		If Items.InteractionsTree.SelectedRows.Count() = 0 Then
			Return False;
		Else
			Return True;
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure SwitchViewModeServer()
	
	InTreeStructure = NOT InTreeStructure;
	
	PagesManagementServer();
	
EndProcedure

&AtServer
Procedure PagesManagementServer()

	If InTreeStructure Then
		Interval = Items.List.Period;
		Commands.SwitchViewMode.ToolTip = NStr("ru = 'Установить режим просмотра в виде списка'; en = 'Set view mode as a list'; pl = 'Ustaw tryb widoku jako lista';es_ES = 'Establecer el modo de vista como una lista';es_CO = 'Establecer el modo de vista como una lista';tr = 'Görüntüleme modunu liste olarak ayarla';it = 'Impostare modalità visualizzazione come elenco';de = 'Ansichtsmodus als Liste festlegen'");
		Items.TreeListPages.CurrentPage = Items.TreePage;
		FillInteractionsTree();
	Else
		
		DateForFilter = CurrentSessionDate();
		Items.List.Period = Interval;
		Commands.SwitchViewMode.ToolTip = NStr("ru = 'Установить режим просмотра в виде дерева'; en = 'Set view mode as a tree'; pl = 'Ustaw tryb widoku jako drzewo';es_ES = 'Establecer el modo de vista como un árbol';es_CO = 'Establecer el modo de vista como un árbol';tr = 'Görüntüleme modunu ağaç olarak ayarla';it = 'Impostare modalità visualizzazione come albero';de = 'Ansichtsmodus als Baum festlegen'");
		Items.TreeListPages.CurrentPage = Items.ListPage;
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,"Status", DateForFilter, FilterBySubject);
		InteractionsClientServer.QuickFilterListOnChange(ThisObject,"EmployeeResponsible", DateForFilter, FilterBySubject);
		OnChangeTypeServer();
	EndIf;

EndProcedure

&AtServer
Procedure FillInteractionsTree()
	
	If FilterBySubject Then
		FilterScheme = DocumentJournals.Interactions.GetTemplate("InteractionsHierarchySubject");
	Else
		FilterScheme = DocumentJournals.Interactions.GetTemplate("InteractionsHierarchyContact");
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(FilterScheme));
	SettingsComposer.LoadSettings(FilterScheme.DefaultSettings);
	
	If FilterBySubject Then
		CommonClientServer.AddCompositionItem(SettingsComposer.Settings.Filter,
			"Topic", DataCompositionComparisonType.Equal, SubjectForFilter);
	Else
		SettingsComposer.Settings.DataParameters.SetParameterValue("Contact",Contact);
	EndIf;
	
	SettingsComposer.Settings.DataParameters.SetParameterValue("Interval",Interval);
	
	CompositionCustomizerFilter = SettingsComposer.Settings.Filter;
	
	If EmailOnly Then
		
		OtherInteractionsTypesList = New ValueList;
		OtherInteractionsTypesList.Add(Type("DocumentRef.Meeting"));
		OtherInteractionsTypesList.Add(Type("DocumentRef.PlannedInteraction"));
		OtherInteractionsTypesList.Add(Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type", DataCompositionComparisonType.NotInList, OtherInteractionsTypesList);
		
	EndIf;
	
	// The EmployeeResponsible quick filter.
	If NOT EmployeeResponsible.IsEmpty() Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,"EmployeeResponsible",
			DataCompositionComparisonType.Equal, EmployeeResponsible);
	EndIf;
	
	// Quick filter "Status"
	If Status = "ToReview" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Reviewed", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"ReviewAfter", DataCompositionComparisonType.LessOrEqual, CurrentSessionDate());
	ElsIf Status = "Deferred" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Reviewed", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"ReviewAfter", DataCompositionComparisonType.Filled,);
	ElsIf Status = "Reviewed" Then
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Reviewed" ,DataCompositionComparisonType.Equal, True);
	EndIf;
	
	// The "Interaction type" quick filter.
	If InteractionType = "AllMessages" Or EmailOnly Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.InList,EmailTypesList);
		
	ElsIf InteractionType = "IncomingMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.IncomingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark", DataCompositionComparisonType.Equal, False);
		
	ElsIf InteractionType = "MessageDrafts" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark",DataCompositionComparisonType.Equal,False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"OutgoingEmailStatus", DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Draft);
		
	ElsIf InteractionType = "OutgoingMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark",DataCompositionComparisonType.Equal,False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"OutgoingEmailStatus", DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Outgoing);
		
	ElsIf InteractionType = "Sent" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal, Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"DeletionMark", DataCompositionComparisonType.Equal, False);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, "OutgoingEmailStatus",
			DataCompositionComparisonType.Equal, 
			Enums.OutgoingEmailStatuses.Sent);
		
	ElsIf InteractionType = "DeletedMessages" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter, 
			"Type", DataCompositionComparisonType.InList, EmailTypesList);
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"DeletionMark", DataCompositionComparisonType.Equal, True);
		
	ElsIf InteractionType = "Meetings" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type", DataCompositionComparisonType.Equal, Type("DocumentRef.Meeting"));
		
	ElsIf InteractionType = "PlannedInteractions" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type", DataCompositionComparisonType.Equal, Type("DocumentRef.PlannedInteraction"));
		
	ElsIf InteractionType = "PhoneCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal, Type("DocumentRef.PhoneCall"));
		
	ElsIf InteractionType = "OutgoingCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Incoming",DataCompositionComparisonType.Equal,False);
		
	ElsIf InteractionType = "IncomingCalls" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.PhoneCall"));
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Incoming",DataCompositionComparisonType.Equal,True);
		
	ElsIf InteractionType = "SMSMessages" Then
		
		CommonClientServer.AddCompositionItem(CompositionCustomizerFilter,
			"Type",DataCompositionComparisonType.Equal,Type("DocumentRef.SMSMessage"));
		
	EndIf;
	
	DataCompositionTemplate = TemplateComposer.Execute(FilterScheme, SettingsComposer.GetSettings(),,,
		Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// Initializing composition processor.
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	
	TreeObject = FormAttributeToValue("InteractionsTree");
	TreeObject.Rows.Clear();
	
	// Getting the result
	ProcessorOfDataCompositionResultOutputInValuesCollection =
		New DataCompositionResultValueCollectionOutputProcessor;
	ProcessorOfDataCompositionResultOutputInValuesCollection.SetObject(TreeObject);
	ProcessorOfDataCompositionResultOutputInValuesCollection.Output(DataCompositionProcessor);
	
	ValueToFormAttribute(TreeObject,"InteractionsTree");
	
	CaptionPattern = NStr("ru = 'Тип взаимодействий: %1'; en = 'Interaction type: %1'; pl = 'Typ interakcji: %1';es_ES = 'Tipo de interacción: %1';es_CO = 'Tipo de interacción: %1';tr = 'Etkileşim türü: %1';it = 'Tipo interazione: %1';de = 'Interaktionstyp: %1'");
	TypePresentation = Interactions.FiltersListByInteractionsType(EmailOnly).FindByValue(InteractionType).Presentation;
	Items.TreeInteractionType.Title = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, TypePresentation);
	For Each SubmenuItem In Items.TreeInteractionType.ChildItems Do
		If SubmenuItem.Name = ("SetFilterInteractionType_TreeInteractionType_" + InteractionType) Then
			SubmenuItem.Check = True;
		Else
			SubmenuItem.Check = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure FillInteractionsTreeClient()

	FillInteractionsTree();
	ExpandAllTreeRows();
	
EndProcedure

&AtClient
Procedure ExpandAllTreeRows()

	For each UpperLevelRow In InteractionsTree.GetItems() Do
		Items.InteractionsTree.Expand(UpperLevelRow.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessDeletionMarkChangeInTree(VAL SelectedRows,ClearMark);
	
	For each SelectedRow In SelectedRows Do
		
		RowData =InteractionsTree.FindByID(SelectedRow);
		If RowData.DeletionMark = ClearMark Then
			InteractionObject = RowData.Ref.GetObject();
			InteractionObject.SetDeletionMark(Not ClearMark);
			RowData.DeletionMark = NOT RowData.DeletionMark;
			RowData.PictureNumber = ?(ClearMark,
			                               RowData.PictureNumber - ?(RowData.Reviewed,5,10),
			                               RowData.PictureNumber + ?(RowData.Reviewed,5,10));
		EndIf;
	EndDo;
	
EndProcedure 

// Gets an array that is passed as a query parameter when getting contact interactions.
//
// Parameters:
//  Contact  - Ref - a contact for which linked contacts are to be searched.
//
// Returns:
//  Array - 
//
&AtServer
Function ContactParameterDependingOnType(Contact)
	
	ContactsDetailsArray = InteractionsClientServer.ContactsDetails();
	HasAdditionalTables = False;
	QueryText = "";
	ContactTableName = Contact.Metadata().Name;
	
	For each DetailsArrayElement In ContactsDetailsArray Do
		
		If DetailsArrayElement.Name = ContactTableName Then
			QueryText = "SELECT ALLOWED
			|	CatalogContact.Ref AS Contact
			|FROM
			|	Catalog." + DetailsArrayElement.Name + " AS CatalogContact
			|WHERE
			|	CatalogContact.Ref = &Contact";
			
			Link = DetailsArrayElement.Link;
			
			If NOT IsBlankString(Link) Then
				
				QueryText = QueryText + "
				|
				|UNION ALL
				|   
				|SELECT
				|	CatalogContact.Ref 
				|FROM
				|	Catalog." + Left(Link,StrFind(Link,".")-1) + " AS CatalogContact
				|WHERE
				|	CatalogContact." + Right(Link,StrLen(Link) - StrFind(Link,".")) + " = &Contact"; 
				
				HasAdditionalTables = True;
				
			EndIf;
			
		ElsIf DetailsArrayElement.OwnerName = ContactTableName Then
			
			QueryText = QueryText + "
			|
			|UNION ALL
			|
			|SELECT
			|	CatalogContact.Ref
			|FROM
			|	Catalog." + DetailsArrayElement.Name + " AS CatalogContact
			|WHERE
			|	CatalogContact.Owner = &Contact";
			
			HasAdditionalTables = True;
			
		EndIf;
		
	EndDo;
	
	If IsBlankString(QueryText) OR (NOT HasAdditionalTables) Then
		Return New Array;
	Else
		Query = New Query(QueryText);
		Query.SetParameter("Contact",Contact);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Return New Array;
		Else
			Return QueryResult.Unload().UnloadColumn("Contact");
		EndIf;
	EndIf;
	
EndFunction

&AtServer
Procedure SetFilterByContact()

	Query = New Query(
			"SELECT ALLOWED DISTINCT
			|	InteractionsContacts.Interaction AS Ref
			|FROM
			|	DocumentJournal.Interactions AS Interactions
			|		INNER JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
			|		ON Interactions.Ref = InteractionsContacts.Interaction
			|WHERE
			|	InteractionsContacts.Contact IN(&Contact)");
			
	ContactParameterArray = ContactParameterDependingOnType(Contact);
	If ContactParameterArray.Count() = 0 Then
		ContactParameterArray.Add(Contact);
	EndIf;
	
	Query.SetParameter("Contact",ContactParameterArray);
	
	FilterList = New ValueList;
	FilterList.LoadValues(
	Query.Execute().Unload().UnloadColumn("Ref"));
	CommonClientServer.SetDynamicListFilterItem(List, 
		"Ref",FilterList,DataCompositionComparisonType.InList,,True);

EndProcedure

&AtServer
Procedure SetFilterBySubject()

	FilterBySubject = True;
	CommonClientServer.SetDynamicListFilterItem(List, "Topic",
			SubjectForFilter,DataCompositionComparisonType.Equal,,True);
	
EndProcedure

&AtClient
Procedure QuestionOnMarkForDeletionAfterCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ProcessDeletionMarkChangeInTree(Items.InteractionsTree.SelectedRows, AdditionalParameters.HasItemsMarkedForDeletion);
	EndIf;
	
EndProcedure

&AtClient
Procedure DateInputSubmitAfterFinished(EnteredDate, AdditionalParameters) Export

	If EnteredDate <> Undefined Then
		
		Replaced = False;
		DeferReview(EnteredDate,Replaced);
		
		If Items.TreeListPages.CurrentPage = Items.ListPage Then
			
			If Replaced Then
				Items.List.Refresh();
			EndIf;
			
		Else
			
			If Replaced Then
				ExpandAllTreeRows();
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure SelectClosingInterval(SelectedPeriod, AdditionalParameters) Export

	If SelectedPeriod <> Undefined Then
		Interval = SelectedPeriod;
		FillInteractionsTreeClient();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeTypeServer()
	
	Interactions.ProcessFilterByInteractionsTypeSubmenu(ThisObject);
	
	InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	
EndProcedure


#EndRegion
