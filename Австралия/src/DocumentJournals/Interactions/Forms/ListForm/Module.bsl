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
	
	If Parameters.Property("ChoiceMode") AND Parameters.ChoiceMode = True Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.ChoiceMode = True;
	EndIf;
	
	FileInfobase = Common.FileInfobase();
	
	Interactions.InitializeInteractionsListForm(ThisObject, Parameters);
	DetermineAvailabilityFullTextSearch();
	
	CommonClientServer.SetDynamicListFilterItem(Tabs, "Owner", Users.CurrentUser(),,, True);
	
	AddToNavigationPanel();
	Interactions.FillStatusSubmenu(Items.StatusList, ThisObject);
	Interactions.FillSubmenuByInteractionType(Items.InteractionTypeList, ThisObject);
	
	For Each SubjectType In Metadata.InformationRegisters.InteractionsFolderSubjects.Resources.Topic.Type.Types() Do
		If EmailOnly 
			AND (SubjectType = Type("DocumentRef.Meeting") OR SubjectType = Type("DocumentRef.PhoneCall") 
			OR SubjectType = Type("DocumentRef.PlannedInteraction") OR SubjectType = Type("DocumentRef.SMSMessage")) Then
			Continue;
		EndIf;
		SubjectTypeChoiceList.Add(Metadata.FindByType(SubjectType).FullName(), String(SubjectType));
	EndDo;
	
	InteractionType = ?(EmailOnly, "AllMessages","All");
	Status = "All";
	
	CurrentNavigationPanelName = CommonClientServer.StructureProperty(Parameters, "CurrentNavigationPanelName");
	CurrentRef = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
	If ValueIsFilled(CurrentRef) Then
		PrepareFormSettingsForCurrentRefOutput(CurrentRef);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	PlacementParameters.Insert("CommandBar", Items.NavigationPanelListGroup.ChildItems.NavigationOptionCommandBar);
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
	Interactions.FillListOfDocumentsAvailableForCreation(DocumentsAvailableForCreation);
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	If Parameters.Property("CurrentNavigationPanelName") Then
		Settings.Delete("CurrentNavigationPanelName");
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If IsBlankString(CurrentNavigationPanelName) Or Items.Find(CurrentNavigationPanelName) = Undefined Then
		CurrentNavigationPanelName = "SubjectPage";
	ElsIf CurrentNavigationPanelName = "PropertiesPage" Then
		If AddlAttributesPropertiesTable.FindRows(New 
				Structure("AddlAttributeInfo",CurrentPropertyOfNavigationPanel)).Count() = 0 Then
			CurrentNavigationPanelName = "SubjectPage";
		EndIf;
	EndIf;
	
	Items.NavigationPanelPages.CurrentPage = Items[CurrentNavigationPanelName];
	
	Status = Settings.Get("Status");
	If Status <> Undefined Then
		Settings.Delete("Status");
	EndIf;
	If Not UseReviewedFlag Then
		Status = "All";
	EndIf;
	If ValueIsFilled(Status) Then
		OnChangeStatusServer(False);
	EndIf;

	EmployeeResponsible = Settings.Get("EmployeeResponsible");
	If EmployeeResponsible <> Undefined Then
		OnChangeEmployeeResponsibleServer(False);
		Settings.Delete("EmployeeResponsible");
	EndIf;
	
	Interactions.OnImportInteractionsTypeFromSettings(ThisObject, Settings);
	
	OnChangeTypeServer(False);
	UpdateNavigationPanelAtServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_InteractionTabs") Then
		If Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
			Items.Tabs.Refresh();
			ProcessNavigationPanelRowActivation();
		EndIf;
	ElsIf Upper(EventName) = Upper("Write_EmailFolders") 
		Or Upper(EventName) = Upper("MessageProcessingRulesApplied")
		Or Upper(EventName) = Upper("SendAndReceiveEmailDone") Then
		If Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
			RefreshNavigationPanel();
			RestoreExpandedTreeNodes();
		EndIf;
	ElsIf Upper(EventName) = Upper("InteractionSubjectEdit") Then
		If Items.NavigationPanelPages.CurrentPage = Items.SubjectPage Then
			RefreshNavigationPanel();
		EndIf;
	EndIf;
	
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If IsBlankString(CurrentNavigationPanelName) 
		Or IsBlankString(Status) 
		Or IsBlankString(InteractionType)  Then
		
		SetInitialValuesOnOpen();
		
	EndIf;
	
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtServer
Procedure SetInitialValuesOnOpen()
	
	Items.NavigationPanelPages.CurrentPage = Items.SubjectPage;
	Status = "All";
	InteractionType = "All";
	OnChangeStatusServer(False);
	OnChangeTypeServer(False);
	UpdateNavigationPanelAtServer();

EndProcedure

&AtClient
Procedure NavigationProcessing(NavigationObject, StandardProcessing)
	If Not ValueIsFilled(NavigationObject) Or NavigationObject = Items.List.CurrentRow Then
		Return;
	EndIf;
	
	NavigationProcessingAtServer(NavigationObject);
	RestoreExpandedTreeNodes();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceContext = "EmployeeResponsibleExecute" Then
		
		If SelectedValue <> Undefined Then
			SetEmployeeResponsible(SelectedValue, Undefined);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "EmployeeResponsibleList" Then
		
		If SelectedValue <> Undefined Then
			SetEmployeeResponsible(SelectedValue, Items.List.SelectedRows);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "SubjectExecuteSubjectType" Then
		
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectExecute";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(SelectedValue + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectListSubjectType" Then
		
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		
		ChoiceContext = "SubjectList";
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		OpenForm(SelectedValue + ".ChoiceForm", FormParameters, ThisObject);
		
		Return;
		
	ElsIf ChoiceContext = "SubjectExecute" Then
		
		If SelectedValue <> Undefined Then
			SetSubject(SelectedValue, Undefined);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "SubjectList" Then
		
		If SelectedValue <> Undefined Then
			SetSubject(SelectedValue, Items.List.SelectedRows);
		EndIf;
		
		RestoreExpandedTreeNodes();
		
	ElsIf ChoiceContext = "MoveToFolder" Then
		
		If SelectedValue <> Undefined Then
			
			CurrentItemName = CurrentItem.Name;
			FoldersCurrentData = Items.Folders.CurrentData;
			
			If StrStartsWith(CurrentItemName, "List") Then
				ExecuteTransferToEmailsArrayFolder(Items[CurrentItemName].SelectedRows, SelectedValue);
			Else
				SetFolderParent(FoldersCurrentData.Value, SelectedValue);
			EndIf;
			
			RestoreExpandedTreeNodes();
			
		EndIf;
		
	EndIf;
	
	ChoiceContext = Undefined;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NavigationPanelOnActivateRow(Item)
	
	If Item.Name = "Subjects" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.SubjectPage Then
		Return;
	ElsIf Item.Name = "Contacts" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.ContactPage Then
		Return;
	ElsIf Item.Name = "Tabs" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.TabsPage Then
		Return;
	ElsIf Item.Name = "Properties" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.PropertiesPage Then
		Return;
	ElsIf Item.Name = "Folders" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.FoldersPage Then
		Return;
	ElsIf Item.Name = "Categories" 
		AND Items.NavigationPanelPages.CurrentPage <> Items.CategoriesPage Then
		Return;
	EndIf;
	
	If DoNotTestNavigationPanelActivation Then
		DoNotTestNavigationPanelActivation = False;
	Else
		AttachIdleHandler("ProcessNavigationPanelRowActivation", 0.2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleOnChange(Item)
	
	OnChangeEmployeeResponsibleServer(True);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure InteractionTypeOnChange(Item)
	
	OnChangeTypeServer();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure ListOnChange(Item)
	
	RefreshNavigationPanel();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure PersonalSettings(Command)
	
	OpenForm("DocumentJournal.Interactions.Form.EmailOperationSettings", , ThisObject);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined AND DisplayReadingPane Then
		If Items.PagesPreview.CurrentPage <> Items.PreviewPlainTextPage Then
			Items.PagesPreview.CurrentPage = Items.PreviewPlainTextPage;
		EndIf;
		Preview = "";
		HTMLPreview = "<HTML><BODY></BODY></HTML>";
		InteractionPreviewGeneratedFor = Undefined;
		
	Else
		
		If CorrectChoice(Item.Name,True) 
			AND InteractionPreviewGeneratedFor <> Items.List.CurrentData.Ref Then
			
			If Items.List.SelectedRows.Count() = 1 Then
				
				AttachIdleHandler("ProcessListRowActivation",0.1,True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Items.List.ChoiceMode Then
		StandardProcessing = False;
		NotifyChoice(RowSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure FoldersSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Item.CurrentData;
	ShowValue(, CurrentData.Value);
	
EndProcedure

&AtClient
Procedure NavigationPanelContactsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Item.CurrentData;
	If Not TypeOf(CurrentData.Contact) = Type("CatalogRef.StringContactInteractions") Then
		ShowValue( ,CurrentData.Contact);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectsNavigationPanelChoice(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		StandardProcessing = False;
		ShowValue( ,CurrentData.Topic);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectsNavigationPanelBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure SubjectsNavigationPanelBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ContactsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ContactsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure FoldersBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	Cancel = True;
	
	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.HasEditPermission = 0 Then
		ShowMessageBox(, NStr("ru = 'Недостаточно прав для создания папки.'; en = 'Insufficient rights to create a folder.'; pl = 'Niewystarczające prawa do utworzenia folderu.';es_ES = 'Insuficientes derechos para crear una carpeta.';es_CO = 'Insuficientes derechos para crear una carpeta.';tr = 'Klasör oluşturmak için gerekli yetkiler yok.';it = 'Diritti insufficienti per creare una cartella.';de = 'Unzureichende Rechte zum Erstellen eines Ordners.'"));
		Return;
	EndIf;
		
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Owner", CurrentData.Account);
	If TypeOf(CurrentData.Value) = Type("CatalogRef.EmailMessageFolders") Then
		ParametersStructure.Insert("Parent", CurrentData.Value);
	EndIf;
	
	FormParameters = New Structure("FillingValues", ParametersStructure);
	OpenForm("Catalog.EmailMessageFolders.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FoldersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CurrentData.Value) = Type("CatalogRef.EmailAccounts")
		OR CurrentData.HasEditPermission = 0 OR CurrentData.PredefinedFolder Then
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Удалить папку ""'; en = 'Delete folder ""'; pl = 'Usuń folder ""';es_ES = 'Borrar la carpeta ""';es_CO = 'Borrar la carpeta ""';tr = 'Klasörü sil ""';it = 'Eliminare cartella ""';de = 'Ordner löschen'") + String(CurrentData.Value) 
	+ NStr("ru = '"" и переместить все ее содержимое в папку ""Удаленные""'; en = '"" and transfer all its contents to the ""Deleted"" folder'; pl = '"" i przenieś całą jej zawartość do folderu ""Usunięte pozycje""';es_ES = '"" y transferir todo su contenido a la carpeta ""Eliminados""';es_CO = '"" y transferir todo su contenido a la carpeta ""Eliminados""';tr = '"" ve tüm içeriğini ""Silinenler"" klasörüne taşı';it = '"" e trasferire tutto il suo contenuto nella cartella ""Eliminati""';de = '"" und dessen kompletten Inhalt zu den Ordner ""Gelöscht"" verschieben'");
	
	AdditionalParameters = New Structure("CurrentData", CurrentData);
	OnCloseNotifyHandler = New NotifyDescription("QuestionOnFolderDeletionAfterCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(OnCloseNotifyHandler, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtServer
Function DeleteFolderServer(Folder)
	
	ErrorDescription = "";
	Interactions.ExecuteEmailsFolderDeletion(Folder, ErrorDescription);
	If IsBlankString(ErrorDescription) Then
		RefreshNavigationPanel();
	EndIf;
	
	Return ErrorDescription;
	
EndFunction

&AtClient
Procedure StatusOnChange(Item)
	
	OnChangeStatusServer(True);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure InteractionTypeStatusClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	
	DetailsSPFound.Clear();
	
	If SearchString <> "" Then
		
		ExecuteFullTextSearch();
		
	Else
		AdvancedSearch = False;
		CommonClientServer.SetDynamicListFilterItem(
			List, 
			"Search",
			Undefined,
			DataCompositionComparisonType.Equal,,False);
		Items.DetailSPFound.Visible = AdvancedSearch;
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchStringAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = New ValueList;
	
	FoundItemsCount = 0;
	For each ListItem In Items.SearchString.ChoiceList Do
		If Left(Upper(ListItem.Value), StrLen(TrimAll(Text))) = Upper(TrimAll(Text)) Then
			ChoiceData.Add(ListItem.Value);
			FoundItemsCount = FoundItemsCount + 1;
			If FoundItemsCount > 7 Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure 

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	InteractionsClient.ListBeforeAddRow(Item, Cancel, Clone, EmailOnly, DocumentsAvailableForCreation);
	
EndProcedure

&AtClient
Procedure NavigationPanelTreeNodeBeforeCollapse(Item, Row, Cancel)
	
	TreeName = Item.Name;
	
	If Item.CurrentRow <> Undefined Then
		RowData = Items[TreeName].RowData(Row);
		If RowData <> Undefined Then
			SaveNodeStateInSettings(TreeName, RowData.Value, False);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure NavigationPanelTreeNodeBeforeExpand(Item, Row, Cancel)
	
	TreeName = Item.Name;
	
	If Item.CurrentRow <> Undefined Then
		RowData = Items[TreeName].RowData(Row);
		If RowData <> Undefined Then
			SaveNodeStateInSettings(TreeName, RowData.Value, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure HTMLPreviewOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////
// Processing dragging

&AtClient
Procedure SubjectsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	If (Row = Undefined) OR (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		For each ArrayElement In DragParameters.Value Do
			If InteractionsClientServer.IsInteraction(ArrayElement) Then
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	DragParameters.Action = DragAction.Cancel;

EndProcedure

&AtClient
Procedure SubjectsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		InteractionsServerCall.SetSubjectForInteractionsArray(DragParameters.Value,
			Row, True);
			
	EndIf;
	
	RefreshNavigationPanel();
	
EndProcedure

&AtClient
Procedure FoldersDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	If (Row = Undefined) OR (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	AssignmentRow = Folders.FindByID(Row);
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		If TypeOf(AssignmentRow.Value) = Type("CatalogRef.EmailAccounts") 
			OR AssignmentRow.HasEditPermission = 0 Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
		
		For each ArrayElement In DragParameters.Value Do
			If Not InteractionsClient.IsEmail(ArrayElement) Then
				Continue;
			EndIf;
			
			DragParameters.Action = DragAction.Cancel;
			RowData = Items.List.RowData(ArrayElement);
			If RowData.Account = AssignmentRow.Account Then
				DragParameters.Action = DragAction.Move;
				Return;
			EndIf;
		EndDo;
		DragParameters.Action = DragAction.Cancel;
		
	ElsIf TypeOf(DragParameters.Value) = Type("Number") Then
		
		RowDrag = Folders.FindByID(DragParameters.Value);
		If RowDrag.Account <> AssignmentRow.Account Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
		
		ParentRow = AssignmentRow;
		While TypeOf(ParentRow.Value) <> Type("CatalogRef.EmailAccounts") Do
			If RowDrag = ParentRow Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			ParentRow = ParentRow.GetParent();
		EndDo;
		
	Else
		
		DragParameters.Action = DragAction.Cancel;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FoldersDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	AssignmentRow = Folders.FindByID(Row);
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		ExecuteTransferToEmailsArrayFolder(DragParameters.Value, AssignmentRow.Value);
	ElsIf TypeOf(DragParameters.Value) = Type("Number") Then
		DragRowData = Folders.FindByID(DragParameters.Value);
		If NOT DragRowData.GetParent() = AssignmentRow Then
			SetFolderParent(DragRowData.Value,
			                        ?(TypeOf(AssignmentRow.Value) = Type("CatalogRef.EmailAccounts"),
			                        PredefinedValue("Catalog.EmailMessageFolders.EmptyRef"),
			                        AssignmentRow.Value));
		EndIf;
			
	EndIf;
	
	RefreshNavigationPanel(AssignmentRow.Value);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure FoldersDragStart(Item, DragParameters, Perform)
	
	If DragParameters.Value = Undefined Then
		Return;
	EndIf;
	
	RowData = Folders.FindByID(DragParameters.Value);
	If TypeOf(RowData.Value) = Type("CatalogRef.EmailAccounts") 
		OR RowData.PredefinedFolder OR RowData.HasEditPermission = 0 Then
		Perform = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	ListFileNames = New ValueList;
	
	If TypeOf(DragParameters.Value) = Type("File") 
		AND DragParameters.Value.IsFile() Then
		
		ListFileNames.Add(DragParameters.Value.FullName,DragParameters.Value.Name);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1 
			AND TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each ReceivedFile In DragParameters.Value Do
				If TypeOf(ReceivedFile) = Type("File") AND ReceivedFile.IsFile() Then
					ListFileNames.Add(ReceivedFile.FullName,ReceivedFile.Name);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	FormParameters = New Structure("Attachments", ListFileNames);
	OpenForm("Document.OutgoingEmail.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	UpdateAtServer();
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure SendReceiveEmailExecute(Command)
	
	If NOT FileInfobase Then
		Return;
	EndIf;
	
	ClearMessages();
	
	EmailManagementClient.SendReceiveUserEmail(UUID, ThisObject, Items.List);
	
EndProcedure

&AtClient
Procedure Reply(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("ru = 'Команда ""Ответить"" может быть выполнена только для входящего письма.'; en = 'You can click ""Reply"" only for incoming messages.'; pl = 'Kliknąć ""Odpowiedz"" tylko dla przychodzących wiadomości.';es_ES = 'Puede hacer clic en ""Responder"" sólo para los mensajes entrantes.';es_CO = 'Puede hacer clic en ""Responder"" sólo para los mensajes entrantes.';tr = '""Yanıtla"" komutu sadece gelen iletiler için kullanılabilir.';it = 'È possibile cliccare su ""Rispondere"" solo per i messaggi in entrata.';de = 'Sie können auf ""Antworten"" nur für eingehende Nachrichten klicken.'"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command",CurrentInteraction, "Reply");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	
EndProcedure

&AtClient
Procedure ReplyToAll(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("ru = 'Команда ""Ответить всем"" может быть выполнена только для входящего письма.'; en = 'You can click ""Reply to all"" only for incoming messages.'; pl = 'Można kliknąć ""Odpowiedz wszystkim"" tylko dla przychodzących wiadomości.';es_ES = 'Puede hacer clic en ""Responder a todos"" sólo para los mensajes entrantes.';es_CO = 'Puede hacer clic en ""Responder a todos"" sólo para los mensajes entrantes.';tr = '""Tümünü yanıtla"" komutu sadece gelen iletiler için kullanılabilir.';it = 'È possibile cliccare su ""Rispondere a tutte"" solo per i messaggi in entrata.';de = 'Sie können auf ""Allen antworten"" nur für eingehende Nachrichten klicken.'"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command",CurrentInteraction, "ReplyToAll");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);
	
EndProcedure

&AtClient
Procedure Forward(Command)
	
	If CorrectChoice(Items.List.Name, True) Then
		CurrentInteraction = Items.List.CurrentData.Ref;
		If TypeOf(CurrentInteraction) <> Type("DocumentRef.OutgoingEmail") 
			AND TypeOf(CurrentInteraction) <> Type("DocumentRef.IncomingEmail") Then
			ShowMessageBox(, NStr("ru = 'Команда ""Переслать"" может быть выполнена только для писем.'; en = 'You can click ""Forward"" only for messages.'; pl = 'Można kliknąć ""Przekaż dalej"" tylko dla wiadomości.';es_ES = 'Puede hacer clic en ""Reenviar"" sólo para los mensajes.';es_CO = 'Puede hacer clic en ""Reenviar"" sólo para los mensajes.';tr = '""Yönlendir"" komutu sadece iletiler için geçerlidir.';it = 'È possibile cliccare su ""Inoltrare"" solo per i messaggi.';de = 'Sie können auf ""Weiterleiten"" nur für Nachrichten klicken.'"));
			Return;
		EndIf;
	Else
		Return;
	EndIf;
	
	Basis = New Structure("Basis,Command", CurrentInteraction, "Forward");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.ObjectForm", OpeningParameters);

EndProcedure

&AtClient
Procedure SwitchNavigationPanel(Command)
	
	SwitchNavigationPanelServer(Command.Name);
	RestoreExpandedTreeNodes();
	
EndProcedure 

&AtClient
Procedure SetNavigationMethodByContact(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodBySubject(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodByTabs(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure SetNavigationMethodByFolders(Command)
	
	SwitchNavigationPanel(Command);
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleExecute(Command)
	
	ChoiceContext = "EmployeeResponsibleExecute";
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",True);
	
	OpenForm("Catalog.Users.Form.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EmployeeResponsibleList(Command)
	
	CurrentItemName = Items.List.Name;
	If StrStartsWith(CurrentItemName, "List") AND Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ChoiceContext = "EmployeeResponsibleList";
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",True);
	
	OpenForm("Catalog.Users.Form.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ReviewedExecute(Command)
	
	SetReviewedFlag(Undefined,True);
	RestoreExpandedTreeNodes();

EndProcedure

&AtClient
Procedure MarkAsReviewed(Command)
	
	ReviewedExecuteList(True);
	
EndProcedure

&AtClient
Procedure InteractionsBySubject(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName,True) Then
		Return;
	EndIf;
	
	Topic = Items[CurrentItemName].CurrentData.Topic;
	
	If InteractionsClientServer.IsSubject(Topic) Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Topic", Topic);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "Topic");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	ElsIf InteractionsClientServer.IsInteraction(Topic) Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Topic", Topic);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("InteractionType", "Interaction");
		
		FormParameters = New Structure;
		FormParameters.Insert("Filter", FilterStructure);
		FormParameters.Insert("AdditionalParameters", AdditionalParameters);
		
	Else
		Return;
	EndIf;

	OpenForm(
		"DocumentJournal.Interactions.Form.ParametricListForm",
		FormParameters,
		ThisObject);
	
EndProcedure

&AtClient
Procedure ClearReviewedFlag(Command)
	
	ReviewedExecuteList(False);
	
EndProcedure

&AtClient
Procedure ReviewedExecuteList(FlagValues)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	SetReviewedFlag(Items[CurrentItemName].SelectedRows, FlagValues);
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure SubjectExecute(Command)
	
	ChoiceContext = "SubjectExecuteSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);

EndProcedure

&AtClient
Procedure SubjectList(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ChoiceContext = "SubjectListSubjectType";
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType",,ThisObject);
	
EndProcedure

&AtClient
Procedure AddToTabs(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") AND Not CorrectChoice(CurrentItemName) Then
		ShowMessageBox(, NStr("ru = 'Не выбран элемент для добавления в закладки.'; en = 'Item for adding to tabs is not selected.'; pl = 'Nie wybrano elementu do dodawania do kart.';es_ES = 'No se ha seleccionado el elemento a añadir a las pestañas.';es_CO = 'No se ha seleccionado el elemento a añadir a las pestañas.';tr = 'Sekmelere eklenecek öğe seçilmedi.';it = 'Lelemento da aggiungere alle schede non è selezionato.';de = 'Element für Hinzufügen zu Registerkarten ist nicht ausgewählt.'"));
		Return;
	EndIf;
	
	ItemToAdd = Undefined;
	If StrStartsWith(CurrentItemName, "List") Then
		ItemToAdd = Items[CurrentItemName].SelectedRows;
	ElsIf CurrentItemName = "Properties" Or CurrentItemName = "Categories" Or CurrentItemName = "Folders" Then
		CurrentData = Items[CurrentItemName].CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd = New Structure("Value", CurrentData.Value);
		EndIf;
	ElsIf CurrentItemName = "NavigationPanelSubjects" Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd = New Structure("Value", CurrentData.Topic);
		EndIf;
	Else
		CurrentData = Items[CurrentItemName].CurrentData;
		If CurrentData <> Undefined Then
			ItemToAdd = New Structure("Value,TypeDescription", CurrentData.Value, CurrentData.TypeDescription);
		EndIf;
	EndIf;
	
	If ItemToAdd = Undefined Then
		ShowMessageBox(, NStr("ru = 'Не выбран элемент для добавления в закладки.'; en = 'Item for adding to tabs is not selected.'; pl = 'Nie wybrano elementu do dodawania do kart.';es_ES = 'No se ha seleccionado el elemento a añadir a las pestañas.';es_CO = 'No se ha seleccionado el elemento a añadir a las pestañas.';tr = 'Sekmelere eklenecek öğe seçilmedi.';it = 'Lelemento da aggiungere alle schede non è selezionato.';de = 'Element für Hinzufügen zu Registerkarten ist nicht ausgewählt.'"));
		Return;
	EndIf;
	
	Result = AddToTabsServer(ItemToAdd, CurrentItemName);
	If Not Result.ItemAdded Then
		ShowMessageBox(, Result.ErrorMessageText);
		Return;
	EndIf;
	ShowUserNotification(NStr("ru = 'Добавлены в закладки:'; en = 'Added to tabs:'; pl = 'Dodano do kart:';es_ES = 'Añadido a las pestañas:';es_CO = 'Añadido a las pestañas:';tr = 'Sekmelere eklendi:';it = 'Aggiunto alle schede:';de = 'Zu Registerkarten hinzugefügt:'"),
		Result.ItemURL, Result.ItemPresentation, PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure DeferReviewExecute(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") AND Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	
	AdditionalParameters = New Structure("CurrentItemName", Undefined);
	OnCloseNotifyHandler = New NotifyDescription("ProcessingDateChoiceOnCompletion", ThisObject, AdditionalParameters);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("ru = 'Отработать после'; en = 'Process after'; pl = 'Przetwórz po';es_ES = 'Procesar después';es_CO = 'Procesar después';tr = 'İşle';it = 'Processare dopo';de = 'Bearbeiten nach'"), DateFractions.DateTime);
	
EndProcedure

&AtClient
Procedure DeferListReview(Command)
	
	CurrentItemName = Items.List.Name;
	If Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	ProcessingDate = CommonClient.SessionDate();
	
	AdditionalParameters = New Structure("CurrentItemName", CurrentItemName);
	OnCloseNotifyHandler = New NotifyDescription("ProcessingDateChoiceOnCompletion", ThisObject, AdditionalParameters);
	ShowInputDate(OnCloseNotifyHandler, ProcessingDate, NStr("ru = 'Отработать после'; en = 'Process after'; pl = 'Przetwórz po';es_ES = 'Procesar después';es_CO = 'Procesar después';tr = 'İşle';it = 'Processare dopo';de = 'Bearbeiten nach'"), DateFractions.DateTime);

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
Procedure CreateSMSMessage(Command)
	
	CreateNewInteraction("SMSMessage");
	
EndProcedure

&AtClient
Procedure ApplyProcessingRules(Command)

	CurrentData = Items.Folders.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.HasEditPermission = 0 
		OR TypeOf(CurrentData.Value) = Type("CatalogRef.EmailAccounts") Then
		Return;
	EndIf;
		
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Account", CurrentData.Account);
	ParametersStructure.Insert("ForEmailsInFolder", CurrentData.Value);
	
	OpenForm("Catalog.EmailProcessingRules.Form.RulesApplication", ParametersStructure);
	
EndProcedure

&AtClient
Procedure MoveToFolder(Command)
	
	CurrentItemName = CurrentItem.Name;
	If StrStartsWith(CurrentItemName, "List") AND Not CorrectChoice(CurrentItemName) Then
		Return;
	EndIf;
	
	FoldersCurrentData = Items.Folders.CurrentData;
	If FoldersCurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentItemName = "Folders" Then
		If TypeOf(FoldersCurrentData.Value) = Type("CatalogRef.EmailAccounts") 
			OR FoldersCurrentData.PredefinedFolder Then
			ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для данного объекта'; en = 'Command cannot be executed for this object'; pl = 'Polecenie nie może być wykonane dla tego obiektu';es_ES = 'No se puede ejecutar el comando para este objeto';es_CO = 'No se puede ejecutar el comando para este objeto';tr = 'Komut, bu nesne için yürütülemiyor';it = 'Il comando non può essere eseguito per l''oggetto specificato';de = 'Befehl kann für dieses Objekt nicht ausgeführt werden'"));
			Return;
		ElsIf FoldersCurrentData.HasEditPermission = 0 Then
			ShowMessageBox(, NStr("ru = 'Недостаточно прав для изменения папок.'; en = 'Insufficient rights to change folders.'; pl = 'Niewystarczające prawa do zmiany folderów.';es_ES = 'Insuficientes derechos para cambiar las carpetas.';es_CO = 'Insuficientes derechos para cambiar las carpetas.';tr = 'Klasör değiştirmek için gerekli yetkiler yok.';it = 'Diritti insufficienti per modificare cartelle.';de = 'Unzureichende Rechte zum Ändern der Ordner.'"));
			Return;
		EndIf;
	EndIf;
	
	ChoiceContext = "MoveToFolder";
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner", FoldersCurrentData.Account));
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.EmailMessageFolders.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EditNavigationPanelValue(Command)
	
	Item = CurrentItemNavigationPanelList();
	If Item = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		
		DisplayedValue = Undefined;
		If CurrentData.Property("Contact") AND TypeOf(CurrentData.Contact) <> Type("CatalogRef.StringContactInteractions") Then
			DisplayedValue = CurrentData.Contact;
		ElsIf CurrentData.Property("Topic") Then
			DisplayedValue = CurrentData.Topic;
		ElsIf CurrentData.Property("Value") AND TypeOf(CurrentData.Value) <> Type("String") Then
			DisplayedValue = CurrentData.Value;
		EndIf;
		
		If DisplayedValue <> Undefined Then
			ShowValue(, DisplayedValue);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportantContactsOnly(Command)
	
	ImportantContactsOnly = Not ImportantContactsOnly;
	FillContactsPanel();
	
EndProcedure

&AtClient
Procedure ImportantSubjectsOnly(Command)
	
	ImportantSubjectsOnly = Not ImportantSubjectsOnly;
	FillSubjectsPanel();
	
EndProcedure

&AtClient
Procedure ActiveSubjectsOnly(Command)
	
	ShowAllActiveSubjects = Not ShowAllActiveSubjects;
	FillSubjectsPanel();
	
EndProcedure

&AtClient
Procedure DisplayReadingPane(Command)
	
	DisplayReadingPane = Not DisplayReadingPane;
	ListOnActivateRow(Items.List);
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

&AtClient
Procedure Attachable_ChangeFilterStatus(Command)
	
	ChangeFilterStatusServer(Command.Name);	
	RestoreExpandedTreeNodes();
	
EndProcedure

&AtClient
Procedure Attachable_ChangeFilterInteractionType(Command)

	ChangeFilterInteractionTypeServer(Command.Name);
	RestoreExpandedTreeNodes();

EndProcedure

&AtClient
Procedure EditNavigationPanelView(Command)
	
	NavigationPanelHidden = Not NavigationPanelHidden;
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

&AtClient
Procedure ForwardAsAttachment(Command)
	
	ClearMessages();
	
	If NOT CorrectChoice("List", True) Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData.Type = Type("DocumentRef.IncomingEmail")
		Or (CurrentData.Type = Type("DocumentRef.OutgoingEmail")
		    AND CurrentData.OutgoingEmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent")) Then
		
		Basis = New Structure("Basis,Command",CurrentData.Ref, "ForwardAsAttachment");
		OpeningParameters = New Structure("Basis", Basis);
		OpenForm("Document.OutgoingEmail.Form.DocumentForm", OpeningParameters);
	
	Else
		
		MessageText = NStr("ru = 'Пересылать как вложения можно только отправленные и полученные письма.'; en = 'Only sent and received emails can be forwarded as attachments.'; pl = 'Przekazywać dalej jako załączniki można tylko wysłane i otrzymane wiadomości e-mail.';es_ES = 'Sólo los correos electrónicos enviados y recibidos se pueden reenviar como adjuntos.';es_CO = 'Sólo los correos electrónicos enviados y recibidos se pueden reenviar como adjuntos.';tr = 'Sadece gönderilmiş ve alınmış e-postalar ek olarak yönlendirilebilir.';it = 'Solo le email inviate e ricevute possono essere inoltrate come allegati.';de = 'Nur gesendete und empfangene E-Mails können als Anhang weitergeleitet werden.'");
		ShowMessageBox(, MessageText); 
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	NavigationPanelSubjects.ConditionalAppearance.Items.Clear();
	ContactsNavigationPanel.ConditionalAppearance.Items.Clear();

	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.Date", Items.Date.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.SentReceived", Items.SentReceived.Name);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Properties.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Properties.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Folders.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Folders.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Categories.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Categories.NotReviewed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UseReviewedFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

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
	ItemField.Field = New DataCompositionField(Items.SearchString.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SearchString");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdvancedSearch");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.FieldBackColor);
	
#Region ReviewedContacts

	Item = ContactsNavigationPanel.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Contact");
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("NotReviewedInteractionsCount");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("NotReviewedInteractionsCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);
	
#EndRegion

#Region ReviewedSubjects

	Item = NavigationPanelSubjects.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Topic");
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("NotReviewedInteractionsCount");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("NotReviewedInteractionsCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Greater;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", Metadata.StyleItems.MainListItem.Value);

#EndRegion
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// Processing quick filter change.

&AtServer
Procedure ChangeFilterInteractionTypeServer(CommandName)

	InteractionType = Interactions.InteractionTypeByCommandName(CommandName, EmailOnly);
	OnChangeTypeServer();

EndProcedure

&AtServer
Procedure OnChangeStatusServer(UpdateNavigationPanel)
	
	DateForFilter = CurrentSessionDate();
	InteractionsClientServer.QuickFilterListOnChange(ThisObject, "Status", DateForFilter);
	
	CaptionPattern = NStr("ru = 'Статус: %1'; en = 'Status: %1'; pl = 'Status: %1';es_ES = 'Estado: %1';es_CO = 'Estado: %1';tr = 'Durum: %1';it = 'Stato: %1';de = 'Status: %1'");
	StatusPresentation = Interactions.StatusesList().FindByValue(Status).Presentation;
	Items.StatusList.Title = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, StatusPresentation);
	For Each SubmenuItem In Items.StatusList.ChildItems Do
		If SubmenuItem.Name = ("SetFilterStatus_" + Status) Then
			SubmenuItem.Check = True;
		Else
			SubmenuItem.Check = False;
		EndIf;
	EndDo;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;

EndProcedure

&AtServer
Procedure ChangeFilterStatusServer(CommandName)
	Status = StatusByCommandName(CommandName);
	OnChangeStatusServer(True);
EndProcedure

&AtServer
Function StatusByCommandName(CommandName)
	
	FoundPosition = StrFind(CommandName, "_");
	If FoundPosition = 0 Then
		Return "All";
	EndIf;
	
	RowStatus = Right(CommandName, StrLen(CommandName) - FoundPosition);
	If Interactions.StatusesList().FindByValue(RowStatus) = Undefined Then
		Return "All";
	EndIf;
	
	Return RowStatus;
	
EndFunction

&AtServer
Procedure OnChangeEmployeeResponsibleServer(UpdateNavigationPanel)

	InteractionsClientServer.QuickFilterListOnChange(ThisObject,"EmployeeResponsible");

	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeTypeServer(UpdateNavigationPanel = True)
	
	Interactions.ProcessFilterByInteractionsTypeSubmenu(ThisObject);
	
	InteractionsClientServer.OnChangeFilterInteractionType(ThisObject, InteractionType);
	If UpdateNavigationPanel Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//    Processing activation of list rows and navigation panel.

&AtClient
Procedure ProcessListRowActivation()
	
	HasUnsafeContent = False;
	EnableUnsafeContent = False;
	SetSecurityWarningVisiblity(ThisObject);
	
	ListName = "List";
	
	If CorrectChoice(ListName,True) Then
		
		If DisplayReadingPane Then
			
			PreviewPageName = Items.PagesPreview.CurrentPage.Name;
			If InteractionPreviewGeneratedFor <> Items[ListName].CurrentData.Ref Then
				DisplayInteractionPreview(Items[ListName].CurrentData.Ref, PreviewPageName);
				If PreviewPageName <> Items.PagesPreview.CurrentPage.Name Then
					Items.PagesPreview.CurrentPage = Items[PreviewPageName];
				EndIf;
			EndIf;
			
		EndIf;
		
		If AdvancedSearch Then
			FillDetailsSPFound(Items[ListName].CurrentData.Ref);
		Else
			DetailSPFound = "";
		EndIf;
		
	Else
		
		If DisplayReadingPane Then
			If Items.PagesPreview.CurrentPage <> Items.PreviewPlainTextPage Then
				Items.PagesPreview.CurrentPage = Items.PreviewPlainTextPage;
			EndIf;
			Preview = "";
			HTMLPreview = "<HTML><BODY></BODY></HTML>";
			InteractionPreviewGeneratedFor = Undefined;
		EndIf;
		DetailSPFound = "";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessNavigationPanelRowActivation();
	
	If NavigationPanelHidden Then
		Return;
	EndIf;
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		CurrentData = Items.NavigationPanelContacts.CurrentData;
		If CurrentData <> Undefined Then
			
			If CurrentData.Contact = ValueSetAfterFillNavigationPanel Then
				ValueSetAfterFillNavigationPanel = Undefined;
				Return;
			EndIf;
			
			ChangeFilterList("Contacts",New Structure("Value,TypeDescription",
			                    CurrentData.Contact, Undefined));
			SaveCurrentActiveValueInSettings("Contacts",CurrentData.Contact);
			
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.SubjectPage Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			
			If CurrentData.Topic = ValueSetAfterFillNavigationPanel Then
				ValueSetAfterFillNavigationPanel = Undefined;
				Return;
			EndIf;
			
			ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
			                    CurrentData.Topic, Undefined));
			SaveCurrentActiveValueInSettings("Subjects", CurrentData.Topic);
		Else
			ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
			                    Undefined, Undefined));
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
		CurrentData = Items.Folders.CurrentData;
		If CurrentData <> Undefined Then
			ChangeFilterList("Folders",New Structure("Value,Account",
			                    CurrentData.Value, CurrentData.Account));
			SaveCurrentActiveValueInSettings("Folders", CurrentData.Value);
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
		CurrentData = Items.Tabs.CurrentData;
		If CurrentData <> Undefined AND NOT CurrentData.IsFolder Then
			ChangeFilterList("Tabs",New Structure("Value", CurrentData.Ref));
			SaveCurrentActiveValueInSettings("Tabs", CurrentData.Ref);
		Else
			CreateNavigationPanelFilterGroup();
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		CurrentData = Items.Properties.CurrentData;
		If CurrentData <> Undefined Then
			ChangeFilterList("Properties",New Structure("Value", CurrentData.Value));
			SaveCurrentActiveValueInSettings("Properties", CurrentData.Value);
		EndIf;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		CurrentData = Items.Categories.CurrentData;
		If CurrentData <> Undefined Then
			ChangeFilterList("Categories",New Structure("Value", CurrentData.Value));
			SaveCurrentActiveValueInSettings("Categories", CurrentData.Value);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveCurrentActiveValueInSettings(TreeName, Value)

	If TreeName = "Properties" Then
		TreeName  = "Properties_" + String(CurrentPropertyOfNavigationPanel);
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName",TreeName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Ind = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Ind]);
		EndDo;
	Else
		SettingsTreeRow = NavigationPanelTreesSettings.Add();
		SettingsTreeRow.TreeName = TreeName;
	EndIf;
	
	SettingsTreeRow.CurrentValue = Value;

EndProcedure 

&AtServer
Function CreateNavigationPanelFilterGroup()

	Return CommonClientServer.CreateFilterItemGroup(
	                    InteractionsClientServer.DynamicListFilter(List).Items,
	                    "FIlterNavigationPanel",
	                    DataCompositionFilterItemsGroupType.AndGroup);

EndFunction

&AtServer
Procedure ChangeFilterList(TableName, DataForProcessing);
	
	If TableName = "Subjects" OR TableName = "Contacts" Then
		DynamicListQueryText = Interactions.InteractionsListQueryText(DataForProcessing.Value);
	Else
		DynamicListQueryText = Interactions.InteractionsListQueryText();
	EndIf;
	
	ListPropertiesStructure              = Common.DynamicListPropertiesStructure();
	ListPropertiesStructure.QueryText = DynamicListQueryText;
		
	Common.SetDynamicListProperties(Items.List, ListPropertiesStructure);
	
	FilterGroup = CreateNavigationPanelFilterGroup();
	
	If DataForProcessing.Value = NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'") Then
		
		InteractionsClientServer.DynamicListFilter(List).Items.Delete(FilterGroup);
		Return;
		
	EndIf;
	
	CaptionPattern = "%1 (%2)";
	
	If TableName = "Subjects" Then
		
		FieldName                    = "Topic";
		FilterItemComparisonType = DataCompositionComparisonType.Equal;
		RightValue             = DataForProcessing.Value;
		FilterName = NStr("ru = 'Тема'; en = 'Subject'; pl = 'Temat';es_ES = 'Tema';es_CO = 'Tema';tr = 'Konu';it = 'Soggetto';de = 'Thema'");
		FilterValue = DataForProcessing.Value;
		
	ElsIf TableName = "Folders" Then
		
			FieldName                    = "Type";
			FilterItemComparisonType = DataCompositionComparisonType.InList;
			TypesList = New ValueList;
			TypesList.Add(Type("DocumentRef.IncomingEmail"));
			TypesList.Add(Type("DocumentRef.OutgoingEmail"));
			RightValue             = TypesList;
			
			CommonClientServer.AddCompositionItem(FilterGroup, FieldName,
			                                                       FilterItemComparisonType, RightValue);
			
			FilterValue = DataForProcessing.Value;
			
			If TypeOf(DataForProcessing.Value) = Type("CatalogRef.EmailMessageFolders") Then
				
				FieldName                    = "Folder";
				FilterItemComparisonType = DataCompositionComparisonType.Equal;
				RightValue             = DataForProcessing.Value;
				FilterName = NStr("ru = 'Папка'; en = 'Folder'; pl = 'Folder';es_ES = 'Carpeta';es_CO = 'Carpeta';tr = 'Klasör';it = 'Cartella';de = 'Ordner'");
				
			Else
				
				FieldName                    = "Account";
				FilterItemComparisonType = DataCompositionComparisonType.Equal;
				RightValue             = DataForProcessing.Value;
				FilterName = NStr("ru = 'Учетная запись'; en = 'Account'; pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Account';de = 'Konto'");
				
			EndIf;
		
	ElsIf TableName = "Contacts" Then
		
		FieldName                    = "Contact";
		FilterItemComparisonType = DataCompositionComparisonType.Equal;
		RightValue             = DataForProcessing.Value;
		FilterName = NStr("ru = 'Контакт'; en = 'Contact'; pl = 'Kontakt';es_ES = 'Contacto';es_CO = 'Contacto';tr = 'Kişi';it = 'Contatto';de = 'Kontakt'");
		FilterValue = DataForProcessing.Value;
		
	ElsIf TableName = "Properties" Then
		
		FieldName = "Ref.[" + String(CurrentPropertyOfNavigationPanel) + "]";
		FilterName = String(CurrentPropertyOfNavigationPanel);
		If TypeOf(DataForProcessing.Value) = Type("String") 
			AND DataForProcessing.Value = NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'") Then
			
			FilterItemComparisonType = DataCompositionComparisonType.NotFilled;
			RightValue             = "";
			FilterValue = NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'");
			
		Else
			
			FilterItemComparisonType = DataCompositionComparisonType.Equal;
			RightValue             = DataForProcessing.Value;
			FilterValue = DataForProcessing.Value;
			
		EndIf;
		
	ElsIf TableName = "Categories" Then
		
		FieldName =  "Ref.[" + String(DataForProcessing.Value) + "]";
		FilterItemComparisonType = DataCompositionComparisonType.Equal;
		RightValue             = True;
		FilterName      = NStr("ru = 'Категория'; en = 'Category'; pl = 'Kategoria';es_ES = 'Categoría';es_CO = 'Categoría';tr = 'Kategori';it = 'Categoria';de = 'Kategorie'");
		FilterValue = String(DataForProcessing.Value);
		
	ElsIf TableName = "Tabs" Then
		
		CompositionSetup = DataForProcessing.Value.SettingsComposer.Get();
		If CompositionSetup = Undefined Then
			Return;
		EndIf;
		CompositionSchema = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
		SchemaURL = PutToTempStorage(CompositionSchema ,UUID);
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		
		SettingsComposer.LoadSettings(CompositionSetup);
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
		
		CopyFilter(FilterGroup,SettingsComposer.Settings.Filter);
		NavigationPanelTitle   = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, NStr("ru = 'Закладка'; en = 'Tab'; pl = 'Karta';es_ES = 'Pestaña';es_CO = 'Pestaña';tr = 'Sekme';it = 'Scheda';de = 'Registerkarte'"), DataForProcessing.Value);
		
		Return;
		
	Else
		
		NavigationPanelTitle = "";
		Return;
		
	EndIf;
	
	NavigationPanelTitleTooltip = StringFunctionsClientServer.SubstituteParametersToString(CaptionPattern, FilterValue, FilterName);
	NavigationPanelTitle = FilterValue;
	If StrLen(NavigationPanelTitle) > 30 Then
		NavigationPanelTitle = Left(NavigationPanelTitle, 27) + "...";
	EndIf;
	CommonClientServer.AddCompositionItem(FilterGroup ,FieldName, 
	                                                       FilterItemComparisonType, RightValue);
	
EndProcedure

&AtServer
Procedure DisplayInteractionPreview(InteractionsDocumentRef, CurrentPageName)
	
	If TypeOf(InteractionsDocumentRef) = Type("DocumentRef.IncomingEmail") Then
		
		CurrentPageName = Items.HTMLPreviewPage.Name;
		HTMLPreview = Interactions.GenerateHTMLTextForIncomingEmail(InteractionsDocumentRef, False, False,
			Not EnableUnsafeContent, HasUnsafeContent);
		Preview = "";
		
	ElsIf TypeOf(InteractionsDocumentRef) = Type("DocumentRef.OutgoingEmail") Then
		
		CurrentPageName = Items.HTMLPreviewPage.Name;
		HTMLPreview = Interactions.GenerateHTMLTextForOutgoingEmail(InteractionsDocumentRef, False, False,
			Not EnableUnsafeContent, HasUnsafeContent);
		Preview = "";
		
	Else
		HasUnsafeContent = False;
		
		CurrentPageName = Items.PreviewPlainTextPage.Name;
		If TypeOf(InteractionsDocumentRef) = Type("DocumentRef.SMSMessage") Then
			Preview = InteractionsDocumentRef.MessageText;
		Else
			Preview = InteractionsDocumentRef.Details;
		EndIf;
		HTMLPreview = "<HTML><BODY></BODY></HTML>";
		
	EndIf;
	
	If StrFind(HTMLPreview,"<BODY>") = 0 Then
		HTMLPreview = "<HTML><BODY>" + HTMLPreview + "</BODY></HTML>";
	EndIf;
	
	InteractionPreviewGeneratedFor = InteractionsDocumentRef;
	SetSecurityWarningVisiblity(ThisObject);
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
//    Switching and filling navigation panels.

&AtServer
Procedure SwitchNavigationPanelServer(CommandName)
	
	If CommandName = "SetNavigationMethodByContact" Then
		FillContactsPanel();
		Items.NavigationPanelPages.CurrentPage = Items.ContactPage;
	ElsIf CommandName = "SetNavigationMethodBySubject" Then
		FillSubjectsPanel();
		Items.NavigationPanelPages.CurrentPage = Items.SubjectPage;
	ElsIf CommandName = "SetNavigationMethodByFolders" Then
		FillFoldersTree();
		Items.NavigationPanelPages.CurrentPage = Items.FoldersPage;
	ElsIf CommandName = "SetNavigationMethodByTabs" Then
		Items.NavigationPanelPages.CurrentPage = Items.TabsPage;
	ElsIf CommandName = "SetOptionByCategories" Then
		FillCategoriesTable();
		Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage;
	ElsIf StrFind(CommandName,"SetOptionByProperty") > 0 Then
		FillPropertiesTree(CommandName);
		Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage;
	EndIf;
	
	NavigationPanelHidden = False;
	CurrentNavigationPanelName = Items.NavigationPanelPages.CurrentPage.Name;
	ManageVisibilityOnSwitchNavigationPanel();
	AfterFillNavigationPanel();

EndProcedure

&AtServer
Procedure ManageVisibilityOnSwitchNavigationPanel()
	
	CurrentNavigationPanelPage = Items.NavigationPanelPages.CurrentPage;
	IsFolders    = (CurrentNavigationPanelPage = Items.FoldersPage);
	
	Items.ListContextMenuMoveToFolder.Visible          = IsFolders;
	Items.SentReceived.Visible                            = IsFolders;
	Items.Size.Visible                                        = IsFolders;
	Items.CreateEmailSpecialButtonList.Visible = IsFolders OR EmailOnly;
	Items.ReplyList.Visible                                = IsFolders OR EmailOnly;
	Items.ReplyToAllList.Visible                            = IsFolders OR EmailOnly;
	Items.ForwardList.Visible                               = IsFolders OR EmailOnly;
	Items.SendReceiveMailList.Visible                  = (IsFolders OR EmailOnly) AND FileInfobase;

	Items.Date.Visible                              = NOT IsFolders;
	Items.CreateGroup.Visible                     = NOT IsFolders AND NOT EmailOnly;
	Items.ListContextMenuCopy.Visible  = Not IsFolders AND Not EmailOnly;
	Items.Copy.Visible                       = Not IsFolders AND Not EmailOnly;
	
	Items.PagesPreview.Visible              = DisplayReadingPane;
	Items.DisplayReadingPaneList.Check       = DisplayReadingPane;
	
	Items.InteractionTypeList.Visible =         Not IsFolders;
	If IsFolders Then
		InteractionType = "All";
		OnChangeTypeServer(False);		
	EndIf;	
	
	Items.NavigationPanelGroup.Visible             = NOT NavigationPanelHidden;
	
	ChangeNavigationPanelDisplayCommand = Commands.Find("EditNavigationPanelView");
	If NavigationPanelHidden Then
		Items.EditNavigationPanelView.Picture = PictureLib.RightArrow;
		ChangeNavigationPanelDisplayCommand.ToolTip = NStr("ru = 'Показать панель навигации'; en = 'Show navigation panel'; pl = 'Pokaż panel nawigacyjny';es_ES = 'Mostrar la barra de navegación';es_CO = 'Mostrar la barra de navegación';tr = 'Gezinme panelini göster';it = 'Mostrare pannello di navigazione';de = 'Navigationsbereich anzeigen'");
		ChangeNavigationPanelDisplayCommand.Title = NStr("ru = 'Показать панель навигации'; en = 'Show navigation panel'; pl = 'Pokaż panel nawigacyjny';es_ES = 'Mostrar la barra de navegación';es_CO = 'Mostrar la barra de navegación';tr = 'Gezinme panelini göster';it = 'Mostrare pannello di navigazione';de = 'Navigationsbereich anzeigen'");
	Else
		Items.EditNavigationPanelView.Picture = PictureLib.LeftArrow;
		ChangeNavigationPanelDisplayCommand.ToolTip = NStr("ru = 'Скрыть панель навигации'; en = 'Hide navigation panel'; pl = 'Ukryj panel nawigacyjny';es_ES = 'Ocultar la barra de navegación';es_CO = 'Ocultar la barra de navegación';tr = 'Gezinme panelini gizle';it = 'Nascondere pannello di navigazione';de = 'Navigationsbereich ausblenden'");
		ChangeNavigationPanelDisplayCommand.Title = NStr("ru = 'Скрыть панель навигации'; en = 'Hide navigation panel'; pl = 'Ukryj panel nawigacyjny';es_ES = 'Ocultar la barra de navegación';es_CO = 'Ocultar la barra de navegación';tr = 'Gezinme panelini gizle';it = 'Nascondere pannello di navigazione';de = 'Navigationsbereich ausblenden'");
	EndIf;
	
	SetNavigationPanelViewTitle();
	
EndProcedure

&AtServer
Procedure SetNavigationPanelViewTitle(FilterValue = Undefined)
	
	For each SubordinateItem In Items.SelectNavigationOption.ChildItems Do
		If TypeOf(SubordinateItem) = Type("FormButton") Then
			SubordinateItem.Check = False;
		EndIf;
	EndDo;
	
	If NavigationPanelHidden Then
		Items.SelectNavigationOption.Title = ?(IsBlankString(NavigationPanelTitle), 
		                                              NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'"),
		                                              NavigationPanelTitle);
		Items.SelectNavigationOption.ToolTip = ?(IsBlankString(NavigationPanelTitle),
		                                              NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'") + NavigationPanelTitleTooltip,
		                                              NavigationPanelTitleTooltip);
	Else
	
		If Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
			Items.SelectNavigationOption.Title = NStr("ru = 'По'; en = 'To'; pl = 'Do';es_ES = 'Hasta';es_CO = 'Hasta';tr = 'Bitiş';it = 'A';de = 'An'") + " " + CurrentPropertyPresentation;
			FoundRows = AddlAttributesPropertiesTable.FindRows(New Structure("AddlAttributeInfo",
			                                                          CurrentPropertyOfNavigationPanel));
			If FoundRows.Count() > 0 Then
				Items["AdditionalButtonPropertyNavigationOptionSelection_" + String(FoundRows[0].SequenceNumber)].Check = True;
			EndIf;

		ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
			
			Items.SelectNavigationOption.Title = NStr("ru = 'По закладкам'; en = 'By bookmarks'; pl = 'Wg zakładek';es_ES = 'Por pestañas';es_CO = 'Por pestañas';tr = 'Yer işaretlerine göre';it = 'Per segnalibri';de = 'Nach Lesezeichen'");
			Items.SetNavigationMethodByTabs.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.SubjectPage Then
			
			Items.SelectNavigationOption.Title = NStr("ru = 'По предметам'; en = 'By subjects'; pl = 'Wg tematów';es_ES = 'Por temas';es_CO = 'Por temas';tr = 'Konulara göre';it = 'Per soggetti';de = 'Nach Themen'");
			Items.SetNavigationMethodBySubject.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
			
			Items.SelectNavigationOption.Title = NStr("ru = 'По контактам'; en = 'By contacts'; pl = 'Wg kontaktów';es_ES = 'Por contactos';es_CO = 'Por contactos';tr = 'Kişilere göre';it = 'Per contatti';de = 'Nach Kontakten'");
			Items.SetNavigationMethodByContact.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
			
			Items.SelectNavigationOption.Title = NStr("ru = 'По папкам'; en = 'By folders'; pl = 'Wg folderów';es_ES = 'Por carpetas';es_CO = 'Por carpetas';tr = 'Klasörlere göre';it = 'Per cartelle';de = 'Nach Ordnern'");
			Items.SetNavigationMethodByFolders.Check = True;
			
		ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
			
			Items.SelectNavigationOption.Title = NStr("ru = 'По категориям'; en = 'By categories'; pl = 'Wg kategorii';es_ES = 'Por categorías';es_CO = 'Por categorías';tr = 'Kategorilere göre';it = 'Per categorie';de = 'Nach Kategorien'");
			Items["AdditionalButtonCategoryNavigationOptionSelection"].Check = True;
			
		EndIf;
		
		Items.SelectNavigationOption.ToolTip = NStr("ru = 'Выберите варианта навигации'; en = 'Select navigation option'; pl = 'Wybierz opcję nawigacyjną';es_ES = 'Seleccionar la variante de navegación';es_CO = 'Seleccionar la variante de navegación';tr = 'Gezinme seçeneğini seçin';it = 'Selezionare opzione di navigazione';de = 'Navigationsoption auswählen'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AddRowAll(FormDataCollection, PictureNumber = 0)
	
	If TypeOf(FormDataCollection) = Type("FormDataTree") Then
		NewRow = FormDataCollection.GetItems().Add();
	Else
		NewRow = FormDataCollection.Add();
	EndIf;
	
	NewRow.Value = NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'");
	NewRow.Presentation = NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'");
	NewRow.PictureNumber = PictureNumber;
	
EndProcedure

&AtServer
Procedure FillPropertiesTree(CommandName = "")
	
	Properties.GetItems().Clear();
	
	If Not IsBlankString(CommandName) Then
		
		PropertyNumberInTable = Number(Right(CommandName, 1));
		
		FoundRows = AddlAttributesPropertiesTable.FindRows(New Structure("SequenceNumber", PropertyNumberInTable));
		CurrentPropertyOfNavigationPanel                   = FoundRows[0].AddlAttributeInfo;
		CurrentPropertyOfNavigationPanelIsAttribute = FoundRows[0].IsAttribute;
		CurrentPropertyPresentation                    = FoundRows[0].Presentation;
		
	EndIf;
	
	Items.PropertiesPresentation.Title  = CurrentPropertyPresentation;
	
	Query = New Query;
	ConditionText = "";
	
	ConditionTextByListFilter =  GetQueryTextByListFilter(Query);
	If Not IsBlankString(ConditionTextByListFilter) Then
		Query.Text = ConditionTextByListFilter;
		
		ConditionText = " WHERE
			|(DocumentInteractions.Ref IN
			|	(SELECT DISTINCT
			|		ListFilter.Ref
			|	FROM
			|		ListFilter AS ListFilter))";
	
	EndIf;
	
	If CurrentPropertyOfNavigationPanelIsAttribute Then
		Query.Text = Query.Text + "
		|SELECT ALLOWED
		|	NestedQuery.Value AS Value,
		|	SUM(NestedQuery.NotReviewed) AS NotReviewed,
		|	1 AS PictureNumber,
		|	PRESENTATION(NestedQuery.Value) AS Presentation
		|FROM
		|	(SELECT
		|		DocumentInteractions.Ref AS Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified) AS Value,
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END AS NotReviewed
		|	FROM
		|		Document.OutgoingEmail AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.OutgoingEmail.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + "
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentInteractions.Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.IncomingEmail AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.IncomingEmail.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + "
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentInteractions.Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.Meeting AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.Meeting.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + "
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentInteractions.Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.PhoneCall AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.SMSMessage.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + "
		|
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentInteractions.Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.SMSMessage AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.SMSMessage.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + "
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentInteractions.Ref,
		|		ISNULL(DocumentInteractionsAdditionalAttributes.Value, &NotSpecified),
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END
		|	FROM
		|		Document.PlannedInteraction AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN Document.PlannedInteraction.AdditionalAttributes AS DocumentInteractionsAdditionalAttributes
		|			ON (DocumentInteractionsAdditionalAttributes.Ref = DocumentInteractions.Ref)
		|				AND (DocumentInteractionsAdditionalAttributes.Property = &Property)
		|		" + ConditionText + " ) AS NestedQuery
		|
		|GROUP BY
		|	NestedQuery.Value
		|
		|ORDER BY
		|Value
		|
		|TOTALS BY
		|Value HIERARCHY";
		
	Else
		
		Query.Text = Query.Text + "
		|SELECT ALLOWED
		|	NestedQuery.Value,
		|	SUM(NestedQuery.NotReviewed) AS NotReviewed,
		|	1 AS PictureNumber,
		|	PRESENTATION(NestedQuery.Value) AS Presentation
		|FROM
		|	(SELECT
		|		DocumentInteractions.Ref AS Ref,
		|		CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END AS NotReviewed,
		|		ISNULL(AdditionalInfo.Value, &NotSpecified) AS Value
		|	FROM
		|		DocumentJournal.Interactions AS DocumentInteractions
		|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			ON DocumentInteractions.Ref = InteractionsFolderSubjects.Interaction
		|			LEFT JOIN InformationRegister.AdditionalInfo AS AdditionalInfo
		|			ON DocumentInteractions.Ref = AdditionalInfo.Object
		|				AND (AdditionalInfo.Property = &Property)
		|		" + ConditionText + " ) AS NestedQuery
		|
		|GROUP BY
		|	NestedQuery.Value
		|
		|ORDER BY
		|Value
		|
		|TOTALS BY
		|Value HIERARCHY";
		
	EndIf;
	
	Query.SetParameter("Property",CurrentPropertyOfNavigationPanel);
	Query.SetParameter("NotSpecified", NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'"));
	
	Result = Query.Execute();
	Tree = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	RowsFirstLevel = Properties.GetItems();
	
	For Each Row In Tree.Rows Do
		PropertyRow =  RowsFirstLevel.Add();
		FillPropertyValues(PropertyRow, Row);
		PropertyRow.PictureNumber = ?(TypeOf(PropertyRow.Value) = Type("String"),0,1);
		PropertyRow.Presentation = String(PropertyRow.Value) 
		                               + ?(Row.NotReviewed = 0 Or Not UseReviewedFlag,
		                               "", " (" + String(Row.NotReviewed) + ")");
		AddRowsToNavigationTree(Row, PropertyRow, True, 1);
	EndDo;
	
	AddRowAll(Properties, 2);
	
EndProcedure

&AtServer
Procedure FillSubjectsPanel()
	
	ListParameters = Common.DynamicListPropertiesStructure();
	
	FilterDestination = NavigationPanelSubjects.SettingsComposer.FixedSettings.Filter;
	FilterDestination.Items.Clear();
	
	If ImportantSubjectsOnly Then
		
		Query = New Query;
		QueryTextByFilter = GetQueryTextByListFilter(Query);
		StringToSearchBy = Right(QueryTextByFilter, StrLen(QueryTextByFilter) -  StrFind(QueryTextByFilter,"WHERE") + 1);
		ConditionStringsArray = StrSplit(StringToSearchBy, Chars.LF, False);
		ConditionsTextByDocumentJournal = "";
		ConditionsTextByRegister          = "";
		Ind = 1;
		
		For Each ConditionString In ConditionStringsArray Do
			ConditionString = StrReplace(ConditionString,"&R","&Par");
			If Ind = 2 Then
				ConditionString = " AND " + ConditionString;
			EndIf;
			If StrFind(ConditionString, "InteractionDocumentsLog") Then
				ConditionsTextByDocumentJournal = ConditionsTextByDocumentJournal + ConditionString + Chars.LF;
			ElsIf StrFind(ConditionString, "InteractionsSubjects") Then
				If IsBlankString(ConditionsTextByRegister) Then
					ConditionString = Right(ConditionString, StrLen(ConditionString) - 3);
				EndIf;
				ConditionsTextByRegister = ConditionsTextByRegister + ConditionString + Chars.LF;
			EndIf;
			
			Ind = Ind + 1;
		EndDo;
		
		If Not IsBlankString(ConditionsTextByRegister) Then
			ConditionsTextByRegister = "WHERE" + " " + ConditionsTextByRegister
		EndIf;
		
		DynamicListQueryText = "
		|SELECT
		|	InteractionsSubjectsStates.Topic,
		|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
		|	InteractionsSubjectsStates.LastInteractionDate,
		|	InteractionsSubjectsStates.IsActive AS IsActive,
		|	VALUETYPE(InteractionsSubjectsStates.Topic) AS SubjectType
		|FROM
		|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
		|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
		|					ON InteractionsSubjects.Topic = InteractionsSubjectsStates.Topic
		|							AND InteractionsSubjects.Interaction = InteractionDocumentsLog.Ref
		|							%DocumentJournalConditionText%
		|			%FolderRegisterConnectionText%)";
		
		DynamicListQueryText = StrReplace(DynamicListQueryText, "%DocumentJournalConditionText%", ConditionsTextByDocumentJournal);
		DynamicListQueryText = StrReplace(DynamicListQueryText, "%FolderRegisterConnectionText%", ConditionsTextByRegister);
		
		ListParameters.QueryText = DynamicListQueryText;
		Common.SetDynamicListProperties(Items.NavigationPanelSubjects, ListParameters);
		
		For each QueryParameter In Query.Parameters Do
			If StrStartsWith(QueryParameter.Key, "R") Then
				ParameterName = "Par" + Right(QueryParameter.Key, StrLen(QueryParameter.Key)-1);
			Else
				ParameterName = QueryParameter.Key;
			EndIf;
			CommonClientServer.SetDynamicListParameter(NavigationPanelSubjects, ParameterName, QueryParameter.Value);
		EndDo;
		
	Else
		
		DynamicListQueryText = "
		|SELECT
		|	InteractionsSubjectsStates.Topic,
		|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
		|	InteractionsSubjectsStates.LastInteractionDate,
		|	InteractionsSubjectsStates.IsActive AS IsActive,
		|	VALUETYPE(InteractionsSubjectsStates.Topic) AS SubjectType
		|FROM
		|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
		|					ON InteractionsFolderSubjects.Topic = InteractionsSubjectsStates.Topic
		|							AND InteractionsFolderSubjects.Interaction = InteractionDocumentsLog.Ref)";
		
		ListParameters.QueryText = DynamicListQueryText;
		Common.SetDynamicListProperties(Items.NavigationPanelSubjects, ListParameters);
		
	EndIf;
	
	If ShowAllActiveSubjects Then
		CommonClientServer.SetFilterItem(FilterDestination,"IsActive", True,DataCompositionComparisonType.Equal);
	EndIf;
	
	Items.SubjectsNavigationPanelContextMenuImportantObjectsOnly.Check = ImportantSubjectsOnly;
	Items.SubjectsNavigationPanelContextMenuActiveSubjectsOnly.Check = ShowAllActiveSubjects;

EndProcedure

&AtServer
Procedure FillCategoriesTable()
	
	Categories.Clear();

	Query = New Query;
	ConditionTextAttributes = "";
	ConditionTextInfo  = "";
	
	ConditionTextByListFilter = GetQueryTextByListFilter(Query);
	If Not IsBlankString(ConditionTextByListFilter) Then
		Query.Text = ConditionTextByListFilter;
		
		ConditionTextAttributes = " AND
			|InteractionAdditionalAttributes.Ref IN
			|	(SELECT DISTINCT
			|		ListFilter.Ref
			|	FROM
			|		ListFilter AS ListFilter)";
		
		ConditionTextInfo = " AND
			|AdditionalInfo.Object IN
			|	(SELECT DISTINCT
			|		ListFilter.Ref
			|	FROM
			|		ListFilter AS ListFilter)";
	
	EndIf;
		
	Query.Text = Query.Text + "
	|SELECT ALLOWED
	|	BooleanProperties.AddlAttributeInfo AS Property,
	|	BooleanProperties.IsAttribute
	|INTO BooleanProperties
	|FROM
	|	&BooleanProperties AS BooleanProperties
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PRESENTATION(NestedQuery.Property) AS Presentation,
	|	NestedQuery.Property AS Value,
	|	SUM(NestedQuery.NotReviewed) AS NotReviewed
	|FROM
	|	(SELECT
	|		InteractionAdditionalAttributes.Property AS Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END) AS NotReviewed
	|	FROM
	|		Document.Meeting.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.Meeting AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) " + ConditionTextAttributes + "
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.PhoneCall.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.PhoneCall AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) " + ConditionTextAttributes + "
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.PlannedInteraction.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.PlannedInteraction AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) " + ConditionTextAttributes + "
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.IncomingEmail.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.IncomingEmail AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) " + ConditionTextAttributes + "
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InteractionAdditionalAttributes.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		Document.OutgoingEmail.AdditionalAttributes AS InteractionAdditionalAttributes
	|			INNER JOIN Document.OutgoingEmail AS Interaction
	|			ON InteractionAdditionalAttributes.Ref = Interaction.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionAdditionalAttributes.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		InteractionAdditionalAttributes.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					BooleanProperties.IsAttribute) " + ConditionTextAttributes + "
	|	
	|	GROUP BY
	|		InteractionAdditionalAttributes.Property
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AdditionalInfo.Property,
	|		SUM(CASE
	|				WHEN InteractionsFolderSubjects.Reviewed
	|					THEN 0
	|				ELSE 1
	|			END)
	|	FROM
	|		InformationRegister.AdditionalInfo AS AdditionalInfo
	|			INNER JOIN DocumentJournal.Interactions AS Interactions
	|			ON AdditionalInfo.Object = Interactions.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON Interactions.Ref = InteractionsFolderSubjects.Interaction
	|	WHERE
	|		AdditionalInfo.Property IN
	|				(SELECT
	|					BooleanProperties.Property
	|				FROM
	|					BooleanProperties AS BooleanProperties
	|				WHERE
	|					(NOT BooleanProperties.IsAttribute))
	|		AND VALUETYPE(AdditionalInfo.Object) IN (TYPE(Document.PlannedInteraction), TYPE(Document.Meeting), TYPE(Document.PhoneCall), TYPE(Document.IncomingEmail), TYPE(Document.OutgoingEmail), TYPE(Document.PlannedInteraction), TYPE(Document.SMSMessage))
	|				 " + ConditionTextInfo + "
	|	
	|	GROUP BY
	|		AdditionalInfo.Property) AS NestedQuery
	|
	|GROUP BY
	|	NestedQuery.Property";
	
	Query.SetParameter("BooleanProperties", AddlAttributesPropertiesTableOfBooleanType.Unload());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Categories.Add();
		FillPropertyValues(NewRow,Selection);
		NewRow.PictureNumber = 0;
		NewRow.Presentation = String(Selection.Presentation) 
		                            + ?(Selection.NotReviewed = 0 Or Not UseReviewedFlag,
		                                "", " (" + String(Selection.NotReviewed) + ")");
		
	EndDo;
	
	AddRowAll(Properties, 2);
	
EndProcedure

&AtServer
Procedure FillContactsPanel()
	
	ListPropertiesStructure = Common.DynamicListPropertiesStructure();
	
	If ImportantContactsOnly Then
		
		Query = New Query;
		QueryTextByFilter = GetQueryTextByListFilter(Query);
		StringToSearchBy = Right(QueryTextByFilter, StrLen(QueryTextByFilter) -  StrFind(QueryTextByFilter,"WHERE") + 1);
		ConditionStringsArray = StrSplit(StringToSearchBy, Chars.LF, False);
		ConditionsTextByDocumentJournal = "";
		ConditionsTextByRegister          = "";
		Ind = 1;
		
		For Each ConditionString In ConditionStringsArray Do
			ConditionString = StrReplace(ConditionString,"&R","&Par");
			If Ind = 2 Then
				ConditionString = " AND " + ConditionString;
			EndIf;
			If StrFind(ConditionString, "InteractionDocumentsLog") Then
				ConditionsTextByDocumentJournal = ConditionsTextByDocumentJournal + ConditionString + Chars.LF;
			ElsIf  StrFind(ConditionString, "InteractionsSubjects") Then
				ConditionsTextByRegister = ConditionsTextByRegister + ConditionString + Chars.LF;
			EndIf;
			
			Ind = Ind + 1;
		EndDo;
		
		DynamicListQueryText = 
		"SELECT
		|	InteractionsContactStates.Contact,
		|	InteractionsContactStates.NotReviewedInteractionsCount,
		|	InteractionsContactStates.LastInteractionDate,
		|	3 AS PictureNumber,
		|	VALUETYPE(InteractionsContactStates.Contact) AS ContactType
		|FROM
		|	InformationRegister.InteractionsContactStates AS InteractionsContactStates
		|WHERE
		|	TRUE IN
		|			(SELECT TOP 1
		|				TRUE
		|			FROM
		|				InformationRegister.InteractionsContacts AS InteractionsContacts
		|					INNER JOIN DocumentJournal.Interactions AS InteractionDocumentsLog
		|					ON
		|						InteractionsContacts.Contact = InteractionsContactStates.Contact
		|							AND InteractionsContacts.Interaction = InteractionDocumentsLog.Ref
		|							%DocumentJournalConditionText%
		|					INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
		|					ON
		|						InteractionsContacts.Contact = InteractionsContactStates.Contact
		|							AND InteractionsContacts.Interaction = InteractionsSubjects.Interaction
		|							%FolderRegisterConnectionText%)";
		
		DynamicListQueryText = StrReplace(DynamicListQueryText, "%DocumentJournalConditionText%", ConditionsTextByDocumentJournal);
		DynamicListQueryText = StrReplace(DynamicListQueryText, "%FolderRegisterConnectionText%", ConditionsTextByRegister);
		
		ListPropertiesStructure.QueryText = DynamicListQueryText;
		Common.SetDynamicListProperties(Items.NavigationPanelContacts, ListPropertiesStructure);
		
		For each QueryParameter In Query.Parameters Do
			If StrStartsWith(QueryParameter.Key, "R") Then
				ParameterName = "Par" + Right(QueryParameter.Key, StrLen(QueryParameter.Key)-1);
			Else
				ParameterName = QueryParameter.Key;
			EndIf;
			CommonClientServer.SetDynamicListParameter(ContactsNavigationPanel, ParameterName, QueryParameter.Value);
		EndDo;
		
	Else
		
		DynamicListQueryText = "
		|SELECT
		|	InteractionsContactStates.Contact,
		|	InteractionsContactStates.NotReviewedInteractionsCount,
		|	InteractionsContactStates.LastInteractionDate,
		|	3 AS PictureNumber,
		|	VALUETYPE(InteractionsContactStates.Contact) AS ContactType
		|FROM
		|	InformationRegister.InteractionsContactStates AS InteractionsContactStates";
		
		ListPropertiesStructure.QueryText = DynamicListQueryText;
		Common.SetDynamicListProperties(Items.NavigationPanelContacts, ListPropertiesStructure);
		
	EndIf;
	
	Items.NavigationPanelContactsContextMenuOnlyImportantContacts.Check = ImportantContactsOnly;
	
EndProcedure

&AtServer
Procedure FillFoldersTree()
	
	Folders.GetItems().Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EmailAccounts.Ref AS Account,
	|	EmailMessageFolders.Ref AS Value,
	|	ISNULL(NotReviewedFolders.NotReviewedInteractionsCount, 0) AS NotReviewed,
	|	EmailMessageFolders.PredefinedFolder AS PredefinedFolder,
	|	CASE
	|		WHEN CASE
	|					WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|						THEN EmailAccountSettings.EmployeeResponsibleForFoldersMaintenance = &CurrentUser
	|					ELSE EmailAccounts.AccountOwner = &CurrentUser
	|				END
	|				OR &FullRightsRoleAvailable
	|			THEN 1
	|		ELSE 0
	|	END AS HasEditPermission,
	|	CASE
	|		WHEN NOT EmailMessageFolders.PredefinedFolder
	|			THEN 7
	|		ELSE CASE
	|				WHEN EmailMessageFolders.Description = &Incoming
	|					THEN 1
	|				WHEN EmailMessageFolders.Description = &Sent
	|					THEN 2
	|				WHEN EmailMessageFolders.Description = &Drafts
	|					THEN 3
	|				WHEN EmailMessageFolders.Description = &Outgoing
	|					THEN 4
	|				WHEN EmailMessageFolders.Description = &JunkMail
	|					THEN 5
	|				WHEN EmailMessageFolders.Description = &DeletedItems
	|					THEN 6
	|			END
	|	END AS PictureNumber
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|		ON (EmailMessageFolders.Owner = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.EmailFolderStates AS NotReviewedFolders
	|		ON (NotReviewedFolders.Folder = EmailMessageFolders.Ref)
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailMessageFolders.Owner = EmailAccountSettings.EmailAccount)
	|WHERE
	|	NOT ISNULL(EmailAccountSettings.DoNotUseInIntegratedMailClient, FALSE)
	|	AND NOT EmailMessageFolders.DeletionMark
	|	AND NOT EmailAccounts.DeletionMark
	|	AND (EmailAccounts.AccountOwner = &CurrentUser
	|			OR EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef))
	|
	|ORDER BY
	|	EmailMessageFolders.Code
	|TOTALS
	|	SUM(NotReviewed),
	|	SUM(HasEditPermission)
	|BY
	|	Account,
	|	Value HIERARCHY";
	
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("FullRightsRoleAvailable", Users.IsFullUser());
	Interactions.SetQueryParametersPredefinedFoldersNames(Query);
	Result = Query.Execute();
	Tree = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	RowsFirstLevel = Folders.GetItems();
	
	For Each Row In Tree.Rows Do
		
		AccountRow = RowsFirstLevel.Add();
		AccountRow.Account        = Row.Account;
		AccountRow.Value             = Row.Account;
		AccountRow.PictureNumber        = 0;
		AccountRow.NotReviewed        = Row.NotReviewed;
		AccountRow.HasEditPermission = Row.HasEditPermission;
		AccountRow.Presentation = String(AccountRow.Value) 
		                              + ?(Row.NotReviewed = 0 Or Not UseReviewedFlag,
		                              "", " (" + String(Row.NotReviewed) + ")");
		
		AddRowsToNavigationTree(Row, AccountRow);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddRowsToNavigationTree(ParentString, ParentRow, ExecuteCheck = True, PictureNumber = -1)
	
	For Each Row In ParentString.Rows Do
		
		If ExecuteCheck AND (Row.Value = ParentString.Value Or Row.Value = Undefined) Then
			Continue;
		EndIf;
		
		NewRow = ParentRow.GetItems().Add();
		FillPropertyValues(NewRow,Row);
		
		If Row.PictureNumber = Null AND PictureNumber <> -1 Then
			NewRow.PictureNumber = PictureNumber;
		EndIf;
	
		If InteractionsClientServer.IsInteraction(Row.Value) Then
			DetailsRow = Row.Rows[0];
			NewRow.Presentation = ?(IsBlankString(DetailsRow.Subject), 
				NStr("ru = 'Тема не указана'; en = 'Subject is not specified'; pl = 'Temat nie jest określony';es_ES = 'No se ha especificado el tema';es_CO = 'No se ha especificado el tema';tr = 'Konu belirtilmedi';it = 'Il soggetto non è specificato';de = 'Thema ist nicht angegeben'"), DetailsRow.Subject) + " " + NStr("ru = 'от'; en = 'from'; pl = 'od';es_ES = 'desde';es_CO = 'desde';tr = 'başlangıç';it = 'da';de = 'vom'") + " " 
				+ Format(DetailsRow.Date, "DLF=DT") + ?(Row.NotReviewed = 0 Or Not UseReviewedFlag,
				                                          "", 
				                                          " (" + String(Row.NotReviewed) + ")");
			NewRow.PictureNumber = DetailsRow.PictureNumber;
		Else
			NewRow.Presentation = String(NewRow.Value) 
			         + ?(Row.NotReviewed = 0 Or Not UseReviewedFlag, 
			             "", 
			             " (" + String(Row.NotReviewed) + ")");
			If Row.PictureNumber = Null AND PictureNumber = -1 AND Row.Rows.Count() > 0 Then
				NewRow.PictureNumber = Row.Rows[0].PictureNumber;
			EndIf;
		EndIf;
		
		AddRowsToNavigationTree(Row, NewRow);
		
	EndDo;
	
EndProcedure

&AtServer
Function GetQueryTextByListFilter(Query)
	
	If InteractionsClientServer.DynamicListFilter(List).Items.Count() > 0 Then
		
		SchemaInteractionsFilter = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
		
		TemplateComposer = New DataCompositionTemplateComposer();
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaInteractionsFilter));
		SettingsComposer.LoadSettings(SchemaInteractionsFilter.DefaultSettings);
		
		CopyFilter(SettingsComposer.Settings.Filter, InteractionsClientServer.DynamicListFilter(List),,, True);
		
		If ValueIsFilled(Items.List.Period.StartDate) OR  ValueIsFilled(Items.List.Period.EndDate) Then
			SettingsComposer.Settings.DataParameters.SetParameterValue("Interval", Items.List.Period);
		EndIf;
		
		DataCompositionTemplate = TemplateComposer.Execute(SchemaInteractionsFilter, SettingsComposer.GetSettings(),,,
			Type("DataCompositionValueCollectionTemplateGenerator"));
		
		If DataCompositionTemplate.ParameterValues.Count() = 0 Then
			Return "";
		ElsIf DataCompositionTemplate.ParameterValues.Count() = 2 
			AND (NOT ValueIsFilled(DataCompositionTemplate.ParameterValues.StartDate.Value)) 
			AND (NOT ValueIsFilled(DataCompositionTemplate.ParameterValues.EndDate.Value)) Then
			Return "";
		EndIf;
		
		QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
		
		For each Parameter In DataCompositionTemplate.ParameterValues Do
			Query.Parameters.Insert(Parameter.Name, Parameter.Value);
		EndDo;
		
		QueryText = QueryText +"
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|";
		
		FoundItemFROM = StrFind(QueryText,"FROM");
		If FoundItemFROM <> 0 Then
			QueryText = Left(QueryText,FoundItemFROM - 1) + "  INTO ListFilter
			|  " + Right(QueryText,StrLen(QueryText) - FoundItemFROM + 1);
			
		EndIf;
		
	Else
		
		Return "";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServer
Procedure RefreshNavigationPanel(CurrentRowValue = Undefined, SetDontTestNavigationPanelActivationFlag = True)
	
	CurrentNavigationPanelPage = Items.NavigationPanelPages.CurrentPage;
	
	If CurrentNavigationPanelPage = Items.ContactPage Then
		FillContactsPanel();
	ElsIf CurrentNavigationPanelPage = Items.SubjectPage Then
		FillSubjectsPanel();
	ElsIf CurrentNavigationPanelPage = Items.FoldersPage Then
		FillFoldersTree();
	ElsIf CurrentNavigationPanelPage = Items.PropertiesPage Then
		FillPropertiesTree();
	ElsIf CurrentNavigationPanelPage = Items.CategoriesPage Then
		FillCategoriesTable();
	EndIf;
	
	AfterFillNavigationPanel(SetDontTestNavigationPanelActivationFlag);
	
EndProcedure

&AtServer
Procedure AfterFillNavigationPanel(SetDontTestNavigationPanelActivationFlag = True)
	
	If NOT SetDontTestNavigationPanelActivationFlag Then
		Return;
	EndIf;
	
	ValueSetAfterFillNavigationPanel = Undefined;
	
	Settings = GetSavedSettingsOfNavigationPanelTree(Items.NavigationPanelPages.CurrentPage.Name,
		CurrentPropertyOfNavigationPanel,NavigationPanelTreesSettings);
	
	If Settings = Undefined Then
		Return;
	EndIf;
	
	SettingsValue = Settings.SettingsValue;
	
	If NOT (Items.NavigationPanelPages.CurrentPage = Items.SubjectPage 
		OR Items.NavigationPanelPages.CurrentPage = Items.ContactPage
		OR Items.NavigationPanelPages.CurrentPage = Items.TabsPage) Then
		PositionOnRowAccordingToSavedValue(SettingsValue.CurrentValue, Settings.TreeName);
	EndIf;
	
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		
		Items.NavigationPanelContacts.CurrentRow = InformationRegisters.InteractionsContactStates.CreateRecordKey(New Structure("Contact", SettingsValue.CurrentValue));

			ChangeFilterList("Contacts",New Structure("Value,TypeDescription",
			                    SettingsValue.CurrentValue, Undefined));
			
		ValueSetAfterFillNavigationPanel = SettingsValue.CurrentValue;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
		
		CurrentData = Folders.FindByID(Items.Folders.CurrentRow);
		If CurrentData = Undefined AND Folders.GetItems().Count() > 0 Then
			CurrentData =  Folders.GetItems()[0];
		EndIf;
		
		If CurrentData <> Undefined Then
			ChangeFilterList("Folders",New Structure("Value,Account",
			                   CurrentData.Value, CurrentData.Account));
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.SubjectPage Then
		
		If ValueIsFilled(Items.NavigationPanelSubjects.CurrentRow) Then
			Return;
		EndIf;
		
		Items.NavigationPanelSubjects.CurrentRow = InformationRegisters.InteractionsSubjectsStates.CreateRecordKey(New Structure("Topic", SettingsValue.CurrentValue));
		
		ChangeFilterList("Subjects",New Structure("Value,TypeDescription",
		                    SettingsValue.CurrentValue, Undefined));
		
		ValueSetAfterFillNavigationPanel = SettingsValue.CurrentValue;

	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		
		CurrentData = Properties.FindByID(Items.Properties.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Properties.CurrentRow = FindStringInFormDataTree(Properties,NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'"),"Value",False);
			CurrentData = Properties.FindByID(Items.Properties.CurrentRow);
		EndIf;
		
		If CurrentData <> Undefined Then
			ChangeFilterList("Properties",New Structure("Value", CurrentData.Value));
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		
		CurrentData = Categories.FindByID(Items.Categories.CurrentRow);
		
		If CurrentData = Undefined Then
			Items.Categories.CurrentRow = FindRowInCollectionFormData(Categories,NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'"),"Value");
			CurrentData = Categories.FindByID(Items.Categories.CurrentRow);
		EndIf;
		
		If CurrentData <> Undefined Then
			ChangeFilterList("Categories",New Structure("Value", CurrentData.Value));
		EndIf;
		
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.TabsPage Then
		
		Items.Tabs.CurrentRow = SettingsValue.CurrentValue;
		ChangeFilterList("Tabs", New Structure("Value", SettingsValue.CurrentValue));
		
	EndIf;
	
	DoNotTestNavigationPanelActivation = True;

EndProcedure

&AtServer
Procedure UpdateAtServer()

	RefreshNavigationPanel( ,False);

EndProcedure

&AtServer
Procedure AddToNavigationPanel()
	
	If Not Common.SubsystemExists("StandardSubsystems.Interactions") Then
		Return;
	EndIf;
	
	Sets = New Array;
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_Meeting);
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_PlannedInteraction);
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_PhoneCall);
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_IncomingEmail);
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_OutgoingEmail);
	Sets.Add(Catalogs.AdditionalAttributesAndInfoSets.Document_SMSMessage);
	
	Query = New Query;
	Query.SetParameter("Sets", Sets);
	Query.Text = "
	|SELECT DISTINCT ALLOWED
	|	AdditionalAttributeAndDataSetsAdditionalAttributes.Property,
	|	PRESENTATION(AdditionalAttributeAndDataSetsAdditionalAttributes.Property) AS Presentation,
	|	TRUE AS IsAddlAttribute
	|INTO AddlAttributesAndInfo
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributeAndDataSetsAdditionalAttributes
	|WHERE
	|	AdditionalAttributeAndDataSetsAdditionalAttributes.Ref IN (&Sets)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AdditionalAttributeAndDataSetsAdditionalData.Property,
	|	PRESENTATION(AdditionalAttributeAndDataSetsAdditionalData.Property),
	|	FALSE
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalAttributeAndDataSetsAdditionalData
	|WHERE
	|	AdditionalAttributeAndDataSetsAdditionalData.Ref IN (&Sets)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AddlAttributesAndInfo.Property,
	|	AddlAttributesAndInfo.Presentation,
	|	AddlAttributesAndInfo.IsAddlAttribute,
	|	AdditionalAttributesAndInfo.ValueType
	|FROM
	|	AddlAttributesAndInfo AS AddlAttributesAndInfo
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|		ON AddlAttributesAndInfo.Property = AdditionalAttributesAndInfo.Ref";
	
	Ind = 0;
	TypesDetailsBoolean = New TypeDescription("Boolean");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ValueType = TypesDetailsBoolean Then
			NewRow = AddlAttributesPropertiesTableOfBooleanType.Add();
		Else
			
		NewCommand = Commands.Add("SetOptionByProperty_" + String(Ind));
		NewCommand.Action = "SwitchNavigationPanel";
		
		ItemButtonSubmenu = Items.Add("AdditionalButtonPropertyNavigationOptionSelection_" 
		                       + String(Ind),Type("FormButton"), Items.SelectNavigationOption);
		ItemButtonSubmenu.Type = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName = NewCommand.Name;
		ItemButtonSubmenu.Title = NStr("ru = 'По'; en = 'To'; pl = 'Do';es_ES = 'Hasta';es_CO = 'Hasta';tr = 'Bitiş';it = 'A';de = 'An'") + " " + Selection.Presentation;
			
			NewRow = AddlAttributesPropertiesTable.Add();
			NewRow.SequenceNumber = Ind;
			Ind = Ind + 1;
			
		EndIf;
		
		NewRow.AddlAttributeInfo = Selection.Property;
		NewRow.IsAttribute = Selection.IsAddlAttribute;
		NewRow.Presentation = Selection.Presentation;
		
	EndDo;
	
	If AddlAttributesPropertiesTableOfBooleanType.Count() > 0 Then
	
		NewCommand = Commands.Add("SetOptionByCategories");
		NewCommand.Action = "SwitchNavigationPanel";
		
		ItemButtonSubmenu = Items.Add("AdditionalButtonCategoryNavigationOptionSelection", 
			Type("FormButton"), Items.SelectNavigationOption);
		ItemButtonSubmenu.Type = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName = NewCommand.Name;
		ItemButtonSubmenu.Title = NStr("ru = 'По категориям'; en = 'By categories'; pl = 'Wg kategorii';es_ES = 'Por categorías';es_CO = 'Por categorías';tr = 'Kategorilere göre';it = 'Per categorie';de = 'Nach Kategorien'");
	
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
//    Saving node statuses and navigation panel tree values.

&AtClientAtServerNoContext
Function GetSavedSettingsOfNavigationPanelTree(
	CurrentPageNameOfNavigationPanel,
	CurrentPropertyOfNavigationPanel,
	NavigationPanelTreesSettings)

	If CurrentPageNameOfNavigationPanel = "SubjectPage" Then
		TreeName = "Subjects";
		SettingName = "Subjects";
	ElsIf CurrentPageNameOfNavigationPanel = "ContactPage" Then
		TreeName = "Contacts";
		SettingName = "Contacts";
	ElsIf CurrentPageNameOfNavigationPanel = "CategoriesPage" Then
		TreeName = "Categories";
		SettingName = "Categories";
	ElsIf CurrentPageNameOfNavigationPanel = "FoldersPage" Then
		TreeName = "Folders";
		SettingName = "Folders";
	ElsIf CurrentPageNameOfNavigationPanel = "PropertiesPage" Then
		TreeName = "Properties";
		SettingName = "Properties_" + String(CurrentPropertyOfNavigationPanel);
	ElsIf CurrentPageNameOfNavigationPanel = "TabsPage" Then
		TreeName = "Tabs";
		SettingName = "Tabs";
	Else
		Return Undefined;
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName", SettingName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Ind = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Ind]);
		EndDo;
	Else
		Return Undefined;
	EndIf;
	
	Return New Structure("TreeName,SettingsValue",TreeName,SettingsTreeRow);

EndFunction

&AtClient
Procedure SaveNodeStateInSettings(TreeName, Value, Expansion);
	
	If TreeName = "Properties" Then
		TreeName =  "Properties_" + String(CurrentPropertyOfNavigationPanel);
	EndIf;
	
	FoundRows =  NavigationPanelTreesSettings.FindRows(New Structure("TreeName",TreeName));
	If FoundRows.Count() = 1 Then
		SettingsTreeRow = FoundRows[0];
	ElsIf FoundRows.Count() > 1 Then
		SettingsTreeRow = FoundRows[0];
		For Ind = 1 To FoundRows.Count()-1 Do
			NavigationPanelTreesSettings.Delete(FoundRows[Ind]);
		EndDo;
	Else
		If Expansion Then
			SettingsTreeRow = NavigationPanelTreesSettings.Add();
			SettingsTreeRow.TreeName = TreeName;
		Else
			Return;
		EndIf;
	EndIf;
	
	FoundListItem = SettingsTreeRow.ExpandedNodes.FindByValue(Value);
	
	If Expansion Then
		
		If FoundListItem = Undefined Then
			
			SettingsTreeRow.ExpandedNodes.Add(Value);
			
		EndIf;
		
	Else
		
		If FoundListItem <> Undefined Then
			
			SettingsTreeRow.ExpandedNodes.Delete(FoundListItem);
			
		EndIf;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure RestoreExpandedTreeNodes()
	
	If Items.NavigationPanelPages.CurrentPage = Items.SubjectPage 
		OR Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		AttachIdleHandler("ProcessNavigationPanelRowActivation", 0.2, True);
		Return;
	EndIf;
	
	Settings = GetSavedSettingsOfNavigationPanelTree(Items.NavigationPanelPages.CurrentPage.Name,
		CurrentPropertyOfNavigationPanel,NavigationPanelTreesSettings);
		
	If Settings = Undefined Then
		Return;
	EndIf;
	
	SettingsValue = Settings.SettingsValue;
	
	If Settings.TreeName <> "Categories" Then
		ExpandedNodesIDsMap = New Map;
		
		If SettingsValue.ExpandedNodes.Count() Then
			DetermineExpandedNodesIDs(SettingsValue.ExpandedNodes, 
				ExpandedNodesIDsMap, ThisObject[Settings.TreeName].GetItems());
		EndIf;
		
		For each MapItem In ExpandedNodesIDsMap Do
			Items[Settings.TreeName].Expand(MapItem.Value);
		EndDo;
		
		For each ListItem In SettingsValue.ExpandedNodes Do
			If ExpandedNodesIDsMap.Get(ListItem.Value) = Undefined Then
				SettingsValue.ExpandedNodes.Delete(ListItem);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DetermineExpandedNodesIDs(ExpandedNodesList, IDsMap, TreeRows)

	For each Item In TreeRows Do
		If ExpandedNodesList.FindByValue(Item.Value) <> Undefined Then
			ParentElement = Item.GetParent();
			If ParentElement = Undefined OR IDsMap.Get(ParentElement.Value) <> Undefined Then
				IDsMap.Insert(Item.Value,Item.GetID());
			EndIf;
		EndIf;
		DetermineExpandedNodesIDs(ExpandedNodesList, IDsMap, Item.GetItems());
	EndDo;
		
EndProcedure

&AtServer
Procedure PositionOnRowAccordingToSavedValue(CurrentRowValue,
	                                                             ItemName,
	                                                             RowAll = Undefined)
	
	If CurrentRowValue <> Undefined Then
		If ItemName <> "Categories" Then
			FoundRowID = FindStringInFormDataTree(ThisObject[ItemName],
				CurrentRowValue,"Value",True);
		Else
			FoundRowID = FindRowInCollectionFormData(ThisObject[ItemName],
				CurrentRowValue,"Value");
		EndIf;
		If FoundRowID > 0 Then
			Items[ItemName].CurrentRow = FoundRowID;
		Else
			Items[ItemName].CurrentRow = ?(RowAll = Undefined, 0, RowAll.GetID());
		EndIf;
	Else
		Items[ItemName].CurrentRow = ?(RowAll = Undefined, 0, RowAll.GetID());
	EndIf;

EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions of command processing.

// Set a responsible person for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
//  Responsible person - a responsible person being set.
&AtServer
Procedure SetEmployeeResponsible(EmployeeResponsible, Val DataForProcessing)
	
	UpdateNavigationPanel = False;
	
	If DataForProcessing <> Undefined Then
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction)
				AND Interaction.EmployeeResponsible <> EmployeeResponsible Then
				
				Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
				UpdateNavigationPanel = True;
				
			EndIf;
		EndDo;
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(EmployeeResponsible,"EmployeeResponsible");
		
		For Each Interaction In InteractionsArray Do
			
			Interactions.ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible);
			UpdateNavigationPanel = True;
			
		EndDo; 
		
	EndIf;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel(, NOT IsPanelWithDynamicList(CurrentNavigationPanelName));
	EndIf;
	
EndProcedure

// Set the Reviewed flag for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
&AtServer
Procedure SetReviewedFlag(Val DataForProcessing, FlagValue)
	
	UpdateNavigationPanel = False;
	
	If DataForProcessing <> Undefined Then
		
		InteractionsArray = New Array;
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction) Then
				InteractionsArray.Add(Interaction);
			EndIf;
		EndDo;
		
		Interactions.MarkAsReviewed(InteractionsArray,FlagValue, UpdateNavigationPanel);
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(FlagValue, "Reviewed");
		
		For Each Interaction In InteractionsArray Do
			Interactions.MarkAsReviewed(InteractionsArray,FlagValue, UpdateNavigationPanel);
		EndDo;
		
	EndIf;
	
	If UpdateNavigationPanel Then
		RefreshNavigationPanel(, NOT IsPanelWithDynamicList(CurrentNavigationPanelName));
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function IsPanelWithDynamicList(CurrentNavigationPanelName)

	If CurrentNavigationPanelName = "SubjectPage" OR CurrentNavigationPanelName = "ContactPage" Then
		Return True;
	Else
		Return False;
	EndIf;

EndFunction

&AtServer
Function AddToTabsServer(Val DataForProcessing, FormItemName)
	
	Result = New Structure;
	Result.Insert("ItemAdded", False);
	Result.Insert("ItemURL", "");
	Result.Insert("ItemPresentation", "");
	Result.Insert("ErrorMessageText", "");
		
	CompositionSchema = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
	SchemaURL = PutToTempStorage(CompositionSchema, UUID);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If StrStartsWith(FormItemName, "List") Then
		
		InteractionsList = New ValueList;
		
		For Each Interaction In DataForProcessing Do
			If ValueIsFilled(Interaction) Then
				InteractionsList.Add(Interaction);
			EndIf;
		EndDo;
		
		If InteractionsList.Count() = 0 Then
			Result.ErrorMessageText = NStr("ru = 'Не выбран элемент для добавления в закладки.'; en = 'Item for adding to tabs is not selected.'; pl = 'Nie wybrano elementu do dodawania do kart.';es_ES = 'No se ha seleccionado el elemento a añadir a las pestañas.';es_CO = 'No se ha seleccionado el elemento a añadir a las pestañas.';tr = 'Sekmelere eklenecek öğe seçilmedi.';it = 'L''elemento per aggiungere da schede non è selezionato.';de = 'Element für Hinzufügen zu Registerkarten ist nicht ausgewählt.'");
			Return Result;
		EndIf;
		
		CommonClientServer.AddCompositionItem(SettingsComposer.Settings.Filter,
			"Ref", DataCompositionComparisonType.InList, InteractionsList);
		TabDescription = ?(EmailOnly, NStr("ru = 'Избранные письма'; en = 'Selected emails'; pl = 'Wybrane wiadomości e-mail';es_ES = 'Correos electrónicos seleccionados';es_CO = 'Correos electrónicos seleccionados';tr = 'Seçili e-postalar';it = 'Email selezionate';de = 'Ausgewählte E-Mails'"), NStr("ru = 'Избранные взаимодействия'; en = 'Favorite interactions'; pl = 'Ulubione interakcje';es_ES = 'Interacciones favoritas';es_CO = 'Interacciones favoritas';tr = 'Sık kullanılan etkileşimler';it = 'Interazioni preferite';de = 'Meist genutzte Interaktionen'"));
		If InteractionsList.Count() > 1 Then
			Text = ?(EmailOnly, NStr("ru = 'Выбранные письма (%1)'; en = 'Selected emails (%1)'; pl = 'Wybrane wiadomości e-mail (%1)';es_ES = 'Correos electrónicos seleccionados (%1)';es_CO = 'Correos electrónicos seleccionados (%1)';tr = 'Seçili e-postalar (%1)';it = 'Email selezionate (%1)';de = 'Ausgewählte E-Mails (%1)'"), NStr("ru = 'Выбранные взаимодействия (%1)'; en = 'Selected interactions (%1)'; pl = 'Powiązane interakcje (%1)';es_ES = 'Interacciones seleccionadas (%1)';es_CO = 'Interacciones seleccionadas (%1)';tr = 'Seçili etkileşimler (%1)';it = 'Interazioni selezionate (%1)';de = 'Ausgewählte Interaktionen (%1)'"));
			Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Text, InteractionsList.Count());
		Else
			Result.ItemPresentation = Common.SubjectString(InteractionsList[0].Value);
			Result.ItemURL = GetURL(InteractionsList[0].Value);
		EndIf;
	Else
		
		If DataForProcessing.Value = NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutte';de = 'Alle'") Then
			Result.ErrorMessageText = NStr("ru = 'Закладку без отбора создать нельзя.'; en = 'Cannot create a tab without filter.'; pl = 'Nie można utworzyć karty bez filtru.';es_ES = 'No se puede crear una pestaña sin selección.';es_CO = 'No se puede crear una pestaña sin selección.';tr = 'Filtresiz sekme oluşturulamıyor.';it = 'Impossibile creare scheda senza filtro.';de = 'Kann keine Registerkarte ohne Filter erstellen.'");
			Return Result;
		EndIf;
		
		FilterGroupByNavigationPanel = CommonClientServer.FindFilterItemByPresentation(
		    InteractionsClientServer.DynamicListFilter(List).Items,
		    "FIlterNavigationPanel");
		If FilterGroupByNavigationPanel = Undefined Then
				Result.ErrorMessageText = NStr("ru = 'Не выбран элемент для добавления в закладки.'; en = 'Item for adding to tabs is not selected.'; pl = 'Nie wybrano elementu do dodawania do kart.';es_ES = 'No se ha seleccionado el elemento a añadir a las pestañas.';es_CO = 'No se ha seleccionado el elemento a añadir a las pestañas.';tr = 'Sekmelere eklenecek öğe seçilmedi.';it = 'L''elemento per aggiungere da schede non è selezionato.';de = 'Element für Hinzufügen zu Registerkarten ist nicht ausgewählt.'");
				Return Result;
		EndIf;
		
		CopyFilter(SettingsComposer.Settings.Filter, FilterGroupByNavigationPanel, True);
		If FormItemName = "NavigationPanelSubjects" Then
			
			If Common.RefTypeValue(DataForProcessing.Value) Then
				
				TabDescription       = NStr("ru = 'Предмет'; en = 'Subject'; pl = 'Temat';es_ES = 'Tema';es_CO = 'Tema';tr = 'Konu';it = 'Soggetto';de = 'Thema'") + " = " + String(DataForProcessing.Value); 
				Text = ?(EmailOnly, NStr("ru = 'Письма по предмету %1'; en = 'Emails by subject %1'; pl = 'Wiadomości e-mail według tematu %1';es_ES = 'Correos electrónicos por tema %1';es_CO = 'Correos electrónicos por tema %1';tr = '%1 konulu e-postalar';it = 'Email per soggetto %1';de = 'E-Mails nach Thema %1'"), NStr("ru = 'Взаимодействия по предмету %1'; en = 'Interactions on the subject %1'; pl = 'Interakcje według tematu %1';es_ES = 'Interacciones sobre el tema %1';es_CO = 'Interacciones sobre el tema %1';tr = '%1 konulu etkileşimler';it = 'Interazioni sul soggetto %1';de = 'Interaktionen zum Thema %1'"));
				Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Text, Common.SubjectString(DataForProcessing.Value));
				Result.ItemURL = GetURL(DataForProcessing.Value);
				
			ElsIf DataForProcessing.Value = NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'") Then
				
				TabDescription       = NStr("ru = 'Предмет не указан'; en = 'Subject is not specified'; pl = 'Temat nie jest określony';es_ES = 'No se ha especificado el tema';es_CO = 'No se ha especificado el tema';tr = 'Konu belirtilmedi';it = 'Il soggetto non è specificato';de = 'Thema ist nicht angegeben'");
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма без предмета'; en = 'Emails without subject'; pl = 'Wiadomości e-mail bez tematu';es_ES = 'Correos electrónicos sin tema';es_CO = 'Correos electrónicos sin tema';tr = 'Konusuz e-postalar';it = 'Email senza oggetto';de = 'E-Mail ohne Thema'"), NStr("ru = 'Взаимодействия без предмета'; en = 'Interaction without subject'; pl = 'Interakcja bez tematu';es_ES = 'Interacción sin tema';es_CO = 'Interacción sin tema';tr = 'Konusuz etkileşimler';it = 'Interazioni senza soggetto';de = 'Interaktionen ohne Thema'"));
				
			ElsIf DataForProcessing.Value = NStr("ru = 'Прочие вопросы'; en = 'Other matters'; pl = 'Inne sprawy';es_ES = 'Otros asuntos';es_CO = 'Otros asuntos';tr = 'Diğer sorular';it = 'Altri temi';de = 'Sonstige Fragen'") Then
				
				TabDescription       = NStr("ru = 'Прочие вопросы'; en = 'Other matters'; pl = 'Inne sprawy';es_ES = 'Otros asuntos';es_CO = 'Otros asuntos';tr = 'Diğer sorular';it = 'Altri temi';de = 'Sonstige Fragen'");
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Прочие письма'; en = 'Other emails'; pl = 'Inne wiadomości e-mail';es_ES = 'Otros correos electrónicos';es_CO = 'Otros correos electrónicos';tr = 'Diğer e-postalar';it = 'Altre email';de = 'Sonstige E-Mails'"), NStr("ru = 'Прочие взаимодействия'; en = 'Other interactions'; pl = 'Inne interakcje';es_ES = 'Otras interacciones';es_CO = 'Otras interacciones';tr = 'Diğer etkileşimler';it = 'Altre interazioni';de = 'Sonstige Interaktionen'"));
				
			Else
				
				TabDescription       = NStr("ru = 'Тип предмета'; en = 'Subject type'; pl = 'Typ tematu';es_ES = 'Tipo de tema';es_CO = 'Tipo de tema';tr = 'Konu türü';it = 'Tipo di soggetto';de = 'Thementyp'") + " " + String(DataForProcessing.TypeDescription.Types()[0]);
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма по: %1'; en = 'Emails by: %1'; pl = 'Wiadomości według: %1';es_ES = 'Correos electrónicos por: %1';es_CO = 'Correos electrónicos por: %1';tr = 'E-postalar: %1';it = 'Email per: %1';de = 'E-Mails nach: %1'"), NStr("ru = 'Взаимодействия по: %1'; en = 'Interactions on:%1'; pl = 'Interakcje według:%1';es_ES = 'Interacciones por:%1';es_CO = 'Interacciones por:%1';tr = 'Etkileşimler: %1';it = 'Interazioni su: %1';de = 'Interaktionen in:%1'"));
				Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.TypeDescription.Types()[0]);
				
			EndIf;
			
		ElsIf FormItemName = "Properties" Then
			
			If TypeOf(DataForProcessing.Value) = Type("String") 
				AND DataForProcessing.Value = NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'") Then
				TabDescription       = CurrentPropertyOfNavigationPanel.Description + " " + NStr("ru = 'не указан'; en = 'not specified'; pl = 'nieokreślono';es_ES = 'no especificado';es_CO = 'no especificado';tr = 'belirtilmedi';it = 'non specificato';de = 'keine angabe'");
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма'; en = 'Emails'; pl = 'E-maile';es_ES = 'Direcciones de correo electrónico';es_CO = 'Direcciones de correo electrónico';tr = 'E-postalar';it = 'Email';de = 'E-Mails'"), NStr("ru = 'Взаимодействия'; en = 'Interactions'; pl = 'Interakcje';es_ES = 'Interacciones';es_CO = 'Interacciones';tr = 'Etkileşimler';it = 'Interazioni';de = 'Interaktionen'"));
			Else
				TabDescription       = CurrentPropertyOfNavigationPanel.Description + " = " + String(DataForProcessing.Value);
				Result.ItemPresentation = ?(EmailOnly, 
				                                   NStr("ru = 'Письма с заданным свойством: %1'; en = 'Emails with the specified property: %1'; pl = 'Wiadomości e-mail z określoną właściwością: %1';es_ES = 'Correos electrónicos con la propiedad especificada: %1';es_CO = 'Correos electrónicos con la propiedad especificada: %1';tr = 'Belirtilen özelliğe sahip e-postalar: %1';it = 'Email con la proprietà specificata: %1';de = 'E-Mails mit der angegebenen Eigenschaft: %1'"), 
				                                   NStr("ru = 'Взаимодействия с заданным свойством: %1'; en = 'Interactions with specified property: %1'; pl = 'Interakcje z zadaną właściwością: %1';es_ES = 'Interacciones con la propiedad especificada: %1';es_CO = 'Interacciones con la propiedad especificada: %1';tr = 'Belirtilen özelliğe sahip etkileşimler: %1';it = 'Interazioni con la proprietà specificata: %1';de = 'Interaktionen mit angegebener Eigenschaft: %1'"));
				Result.ItemPresentation = 
					StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			EndIf;
			
		ElsIf FormItemName = "Categories" Then
			
			TabDescription       = NStr("ru = 'Входит в категорию'; en = 'Belongs to the category'; pl = 'Należy do kategorii';es_ES = 'Pertenece a la categoría';es_CO = 'Pertenece a la categoría';tr = 'Kategoriye ait';it = 'Appartiene alla categoria';de = 'Der Kategorie gehört'") + " " + String(DataForProcessing.Value);
			Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма из категории: %1'; en = 'Emails from category: %1'; pl = 'Wiadomości e-mail z kategorii:%1';es_ES = 'Correos electrónicos de la categoría: %1';es_CO = 'Correos electrónicos de la categoría: %1';tr = 'Şu kategoriden e-postalar: %1';it = 'Email dalla categoria: %1';de = 'E-Mails aus Kategorie: %1'"), NStr("ru = 'Взаимодействия из категории: %1'; en = 'Interactions from the category: %1'; pl = 'Interakcje z kategorii:%1';es_ES = 'Interacciones de la categoría: %1';es_CO = 'Interacciones de la categoría: %1';tr = 'Şu kategoriden etkileşimler: %1';it = 'Interazione dalla categoria: %1';de = 'Interaktionen aus der Kategorie: %1'"));
			Result.ItemPresentation = 
				StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			
		ElsIf FormItemName = "Contacts" Then
			
			If Common.RefTypeValue(DataForProcessing.Value) Then
				
				TabDescription       = NStr("ru = 'Контакт'; en = 'Contact'; pl = 'Kontakt';es_ES = 'Contacto';es_CO = 'Contacto';tr = 'Kişi';it = 'Contatto';de = 'Kontakt'") + " = " + String(DataForProcessing.Value); 
				Text = ?(EmailOnly, NStr("ru = 'Письма по контакту %1'; en = 'Emails by contact %1'; pl = 'Wiadomości e-mail według kontaktu:%1';es_ES = 'Correos electrónicos por contacto %1';es_CO = 'Correos electrónicos por contacto %1';tr = '%1 kişisinin e-postaları';it = 'Email per contatto %1';de = 'E-Mails nach Kontakt %1'"), NStr("ru = 'Взаимодействия по контакту %1'; en = 'Interactions by contact %1'; pl = 'Interakcje według konatku:%1';es_ES = 'Interacciones por contacto %1';es_CO = 'Interacciones por contacto %1';tr = '%1 kişisinin etkileşimleri';it = 'Interazione per contatto %1';de = 'Interaktionen nach Kontakt: %1'"));
				Result.ItemPresentation = 
					StringFunctionsClientServer.SubstituteParametersToString(Text, Common.SubjectString(DataForProcessing.Value));
				Result.ItemURL = GetURL(DataForProcessing.Value);
				
			ElsIf DataForProcessing.Value = NStr("ru = 'Контакт не подобран'; en = 'Contact is not selected'; pl = 'Nie wybrano kontaktu';es_ES = 'No se ha seleccionado el contacto';es_CO = 'No se ha seleccionado el contacto';tr = 'Kişi seçilmedi';it = 'Contatto non selezionato';de = 'Kontakt ist nicht ausgewählt'") Then
				
				TabDescription       = NStr("ru = 'Контакт не указан'; en = 'Contact is not specified'; pl = 'Nie określono kontaktu';es_ES = 'No se ha especificado el contacto';es_CO = 'No se ha especificado el contacto';tr = 'Kişi belirtilmedi';it = 'Contatto non specificato';de = 'Kontakt ist nicht angegeben'");
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма без подобранных контактов'; en = 'Emails without selected contacts'; pl = 'Wiadomości e-mail bez wybranych kontaktów';es_ES = 'Correos electrónicos sin contactos seleccionados';es_CO = 'Correos electrónicos sin contactos seleccionados';tr = 'Seçili kişilerin olmadığı e-postalar';it = 'Email senza contatti selezionati';de = 'E-Mails ohne ausgewählte Kontakte'"), NStr("ru = 'Взаимодействия без подобранных контактов'; en = 'Interactions without selected contacts'; pl = 'Interakcje bez wybranych kontaktów';es_ES = 'Interacciones sin contactos seleccionados';es_CO = 'Interacciones sin contactos seleccionados';tr = 'Seçili kişilerin olmadığı etkileşimler';it = 'Interazioni con i contatti selezionati';de = 'Interaktionen ohne ausgewählte Kontakte'"));
				
			Else
				
				TabDescription       = NStr("ru = 'Тип контакта'; en = 'Contact type'; pl = 'Typ kontaktu';es_ES = 'Tipo de contacto';es_CO = 'Tipo de contacto';tr = 'Kişi türü';it = 'Tipo di contatto';de = 'Kontakttyp'") + " " + String(DataForProcessing.TypeDescription.Types()[0]);
				Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма по контактам: %1'; en = 'Emails by contacts: %1'; pl = 'Wiadomości e-mail według konaktów: %1';es_ES = 'Correos electrónicos por contactos %1';es_CO = 'Correos electrónicos por contactos %1';tr = 'Kişilere göre e-postalar: %1';it = 'Email per contatto: %1';de = 'E-Mails nach Kontakt %1'"), NStr("ru = 'Взаимодействия по контактам: %1'; en = 'Interactions by contacts: %1'; pl = 'Interakcje według kontaktów:%1';es_ES = 'Interacciones por contactos %1';es_CO = 'Interacciones por contactos %1';tr = 'Kişilere göre etkileşimler: %1';it = 'Interazioni per contatti: %1';de = 'Interaktionen nach Kontakten: %1'"));
				Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.TypeDescription.Types()[0]);
				
			EndIf;

		ElsIf FormItemName = "Folders" Then
			
			TabDescription       = NStr("ru = 'В папке'; en = 'In folder'; pl = 'W folderze';es_ES = 'En carpeta';es_CO = 'En carpeta';tr = 'Klasörde';it = 'Nella cartella';de = 'Im Ordner'") + " " + String(DataForProcessing.Value);
			Result.ItemPresentation = ?(EmailOnly, NStr("ru = 'Письма в папке: %1'; en = 'Emails are in folder: %1'; pl = 'Wiadomości e-mail są w folderze:%1';es_ES = 'Correos electrónicos en la carpeta: %1';es_CO = 'Correos electrónicos en la carpeta: %1';tr = 'E-postalar klasörde: %1';it = 'Le email sono nella cartella: %1';de = 'E-Mails sind im Ordner: %1'"), NStr("ru = 'Взаимодействия в папке: %1'; en = 'Interactions in the folder: %1'; pl = 'Interakcje w folderze %1';es_ES = 'Interacciones en la carpeta: %1';es_CO = 'Interacciones en la carpeta: %1';tr = 'Etkileşimler klasörde: %1';it = 'Interazioni nella cartella: %1';de = 'Interaktionen im Ordner: %1'"));
			Result.ItemPresentation = StringFunctionsClientServer.SubstituteParametersToString(Result.ItemPresentation, DataForProcessing.Value);
			
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	InteractionsTabs.Ref,
	|	InteractionsTabs.Description,
	|	InteractionsTabs.SettingsComposer
	|FROM
	|	Catalog.InteractionsTabs AS InteractionsTabs
	|WHERE
	|	NOT InteractionsTabs.IsFolder
	|	AND NOT InteractionsTabs.DeletionMark";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If ValueInXML(SettingsComposer.GetSettings()) =  ValueInXML(Selection.SettingsComposer.Get()) Then
			Result.ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Закладка с такими настройками уже существует : %1'; en = 'Tab with these settings already exists : %1'; pl = 'Karta z takimi ustawieniami już istnieje: %1';es_ES = 'La pestaña con esta configuración ya existe : %1';es_CO = 'La pestaña con esta configuración ya existe : %1';tr = 'Bu ayarlara sahip sekme zaten var: %1';it = 'La scheda con queste impostazioni esiste già: %1';de = 'Registerkarte mit diesen Einstellungen existiert bereits: %1'"),
				Selection.Description);
			Return Result;
		EndIf;
	EndDo;
	
	Tab = Catalogs.InteractionsTabs.CreateItem();
	Tab.Owner = Users.AuthorizedUser();
	Tab.Description = TabDescription;
	Tab.SettingsComposer = New ValueStorage(SettingsComposer.GetSettings());
	Tab.Write();
	
	Items.Tabs.Refresh();
	
	Result.ItemAdded = True;
	Return Result;
	
EndFunction

&AtServerNoContext
Function ValueInXML(Value)
	
	Record = New XMLWriter();
	Record.SetString();
	XDTOSerializer.WriteXML(Record, Value);
	Return Record.Close();
	
EndFunction

// Set a subject for selected interactions - the server part.
// Parameters:
//  Interactions - a list of selected interactions.
//  Subject - an interaction subject being set.
&AtServer
Procedure SetSubject(Topic, Val DataForProcessing)
	
	If DataForProcessing <> Undefined Then
		
		Query = New Query;
		Query.Text = "SELECT
		|	Interactions.Ref
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|		INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		ON Interactions.Ref = InteractionsFolderSubjects.Interaction
		|WHERE
		|	InteractionsFolderSubjects.Topic <> &Topic
		|	AND Interactions.Ref IN (&InteractionsArray)";
		
		Query.SetParameter("InteractionsArray",DataForProcessing );
		Query.SetParameter("Topic", Topic);
		
		InteractionsArray = Query.Execute().Unload().UnloadColumn("Ref");
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(Topic, "Topic");
		
	EndIf;
	
	If InteractionsArray.Count() > 0 Then
		InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, Topic, True);
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeferReview(ReviewDate, Val DataForProcessing)
	
	If DataForProcessing <> Undefined Then
		
		InteractionsArray = Interactions.InteractionsArrayForReviewDateChange(DataForProcessing, ReviewDate);
		
	Else
		
		InteractionsArray = GetInteractionsByListFilter(True, "Reviewed");
		
	EndIf;
	
	For Each Interaction In InteractionsArray Do
		
		Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
		Attributes.ReviewAfter        = ReviewDate;
		Attributes.CalculateReviewedItems = False;
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Interaction, Attributes);
		
	EndDo;
	
	If InteractionsArray.Count() > 0 Then
		RefreshNavigationPanel();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateNewInteraction(ObjectType)
	
	CreationParameters = New Structure;
		
	If CurrentNavigationPanelName = "ContactPage" Then
		CurrentData = Items.NavigationPanelContacts.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("Contact", CurrentData.Contact));
		EndIf;
	ElsIf CurrentNavigationPanelName = "SubjectPage" Then
		CurrentData = Items.NavigationPanelSubjects.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("Topic", CurrentData.Topic));
		EndIf;
	ElsIf CurrentNavigationPanelName = "FoldersPage" Then
		CurrentData = Items.Folders.CurrentData;
		If CurrentData <> Undefined Then
			CreationParameters.Insert("FillingValues", New Structure("Account", CurrentData.Account));
		EndIf;
	EndIf;
	
	InteractionsClient.CreateNewInteraction(ObjectType, CreationParameters, ThisObject);

EndProcedure

&AtServer
Function GetInteractionsByListFilter(AdditionalFilterAttributeValue = Undefined, AdditionalFilterAttributeName = "")
	
	Query = New Query;
	
	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		FilterScheme = DocumentJournals.Interactions.GetTemplate("SchemaFilterInteractionsContact");
	Else
		FilterScheme = DocumentJournals.Interactions.GetTemplate("SchemaInteractionsFilter");
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer();
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(FilterScheme));
	SettingsComposer.LoadSettings(FilterScheme.DefaultSettings);
	
	CopyFilter(SettingsComposer.Settings.Filter, InteractionsClientServer.DynamicListFilter(List));
	
	// Adding a filter with a comparison kind NOT for group commands.
	If AdditionalFilterAttributeValue <> Undefined Then
		FilterItem = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField(AdditionalFilterAttributeName);
		FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
		FilterItem.RightValue = AdditionalFilterAttributeValue;
	EndIf;
	
	DataCompositionTemplate = TemplateComposer.Execute(FilterScheme, SettingsComposer.GetSettings()
		,,, Type("DataCompositionValueCollectionTemplateGenerator"));
	
	QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
	
	For each Parameter In DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

&AtServer
Procedure SetFolderParent(Folder, NewParent)
	
	Interactions.SetFolderParent(Folder, NewParent);
	RefreshNavigationPanel();
	
EndProcedure

&AtServer
Procedure ExecuteTransferToEmailsArrayFolder(VAL EmailsArray, Folder)

	Interactions.SetFolderForEmailsArray(EmailsArray, Folder);
	RefreshNavigationPanel(Folder);

EndProcedure

/////////////////////////////////////////////////////////////////////////////////////////
// Full-text search

&AtServer
Procedure DetermineAvailabilityFullTextSearch() 
	
	If GetFunctionalOption("UseFullTextSearch") 
		AND FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then
		SearchHistory = Common.CommonSettingsStorageLoad("InteractionSearchHistory", "");
		If SearchHistory <> Undefined Then
			Items.SearchString.ChoiceList.LoadValues(SearchHistory);
		EndIf;
	Else
		Items.SearchString.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteFullTextSearch()
	
	FoundItemsCount = 0;
	ErrorText = FindInteractionsFullTextSearch(FoundItemsCount);
	If ErrorText = Undefined Then
		AdvancedSearch = True;
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Найдено %1 %2.'; en = 'Found %1 %2.'; pl = 'Znaleziono %1 %2.';es_ES = 'Encontrado %1 %2.';es_CO = 'Encontrado %1 %2.';tr = 'Bulundu %1 %2.';it = 'Trovato %1 %2.';de = 'Gefunden %1 %2.'"),
			?(EmailOnly,NStr("ru = 'писем'; en = 'emails'; pl = 'wiadomości e-mail';es_ES = 'correos electrónicos';es_CO = 'correos electrónicos';tr = 'e-postalar';it = 'email';de = 'E-Mails'"), NStr("ru = 'взаимодействий'; en = 'interactions'; pl = 'interakcje';es_ES = 'interacciones';es_CO = 'interacciones';tr = 'etkileşimler';it = 'interazioni';de = 'interaktionen'")) + ": ",
			String(FoundItemsCount));
		ShowUserNotification(NotificationText);
		CurrentData = Items.List.CurrentData;
		If CurrentData <> Undefined Then
			FillDetailsSPFound(Items.List.CurrentData.Ref);
		Else
			DetailSPFound = "";
		EndIf;
	Else
		If NOT ErrorText = NStr("ru = 'Ничего не найдено'; en = 'No results found'; pl = 'Brak rezultatów wyszukiwania';es_ES = 'No hay resultados encontrados';es_CO = 'No hay resultados encontrados';tr = 'Sonuç bulunamadı';it = 'Nessun risultato trovato';de = 'Keine Ergebnisse gefunden'") Then
			ShowUserNotification(ErrorText);
		Else
			AdvancedSearch = False;
		EndIf;
	EndIf;
	
	Items.DetailSPFound.Visible = AdvancedSearch;
	
EndProcedure

&AtServer
Function FindInteractionsFullTextSearch(ItemsCount)

	// set search parameters
	SearchArea = New Array;
	BatchSize = 200;
	
	FullTextSearchString = SearchString;
	If StrFind(FullTextSearchString, "*") = 0 Then
		FullTextSearchString = "*" + FullTextSearchString + "*";
	EndIf;	
	
	SearchList = FullTextSearch.CreateList(FullTextSearchString, BatchSize);
	SearchArea.Add(Metadata.Documents.IncomingEmail);
	SearchArea.Add(Metadata.Documents.OutgoingEmail);
	SearchArea.Add(Metadata.Catalogs.IncomingEmailAttachedFiles);
	SearchArea.Add(Metadata.Catalogs.OutgoingEmailAttachedFiles);
	SearchArea.Add(Metadata.InformationRegisters.InteractionsFolderSubjects);

	If Not EmailOnly Then
		SearchArea.Add(Metadata.Documents.PhoneCall);
		SearchArea.Add(Metadata.Documents.Meeting);
		SearchArea.Add(Metadata.Documents.PlannedInteraction);
		SearchArea.Add(Metadata.Catalogs.PhoneCallAttachedFiles);
		SearchArea.Add(Metadata.Catalogs.MeetingAttachedFiles);
		SearchArea.Add(Metadata.Catalogs.PlannedInteractionAttachedFiles);
	EndIf;
	SearchList.SearchArea = SearchArea;

	SearchList.FirstPart();

	// Return if search has too many results.
	If SearchList.TooManyResults() Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		Return NStr("ru = 'Слишком много результатов, уточните запрос.'; en = 'Too many results, narrow your search.'; pl = 'Zbyt dużo wyników, uściślij zapytanie.';es_ES = 'Hay demasiados resultados, reduzca los criterios de su búsqueda.';es_CO = 'Hay demasiados resultados, reduzca los criterios de su búsqueda.';tr = 'Çok fazla sonuç var; aramanızı daraltın.';it = 'Troppi risultati, affinare la ricerca.';de = 'Zu viele Ergebnisse, verengen Sie die Anfrage.'");
	EndIf;

	// Return if search has no results.
	If SearchList.TotalCount() = 0 Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		Return NStr("ru = 'Ничего не найдено'; en = 'No results found'; pl = 'Brak rezultatów wyszukiwania';es_ES = 'No hay resultados encontrados';es_CO = 'No hay resultados encontrados';tr = 'Sonuç bulunamadı';it = 'Nessun risultato trovato';de = 'Keine Ergebnisse gefunden'");
	EndIf;
	
	ItemsCount = SearchList.TotalCount();
	
	StartPosition = 0;
	EndPosition = ?(ItemsCount > BatchSize, BatchSize, ItemsCount) - 1;
	HasNextBatch = True;

	// Process the FTS results by portions.
	While HasNextBatch Do
		For ItemsCounter = 0 To EndPosition Do
			
			Item = SearchList.Get(ItemsCounter);
			NewRow = DetailsSPFound.Add();
			FillPropertyValues(NewRow,Item);
			If InteractionsClientServer.IsAttachedInteractionsFile(Item.Value) Then
				NewRow.Interaction = Item.Value.FileOwner;
			ElsIf TypeOf(Item.Value) = Type("InformationRegisterRecordKey.InteractionsFolderSubjects") Then
				NewRow.Interaction =  Item.Value.Interaction;
			Else
				NewRow.Interaction = Item.Value;
			EndIf;
			
		EndDo;
		StartPosition = StartPosition + BatchSize;
		HasNextBatch = (StartPosition < ItemsCount - 1);
		If HasNextBatch Then
			EndPosition = 
			?(ItemsCount > StartPosition + BatchSize, BatchSize,
			ItemsCount - StartPosition) - 1;
			SearchList.NextPart();
		EndIf;
	EndDo;
	
	If DetailsSPFound.Count() = 0 Then
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			Documents.IncomingEmail.EmptyRef(),
			DataCompositionComparisonType.Equal,, True);
		Items.SearchString.BackColor = StyleColors.ErrorFullTextSearchBackground;
		Return NStr("ru = 'Ничего не найдено.'; en = 'None found.'; pl = 'Nic nie znaleziono.';es_ES = 'No se ha encontrado ninguno.';es_CO = 'No se ha encontrado ninguno.';tr = 'Bulunamadı.';it = 'Zero trovati.';de = 'Keine Ergebnisse.'");
	EndIf;
	
	// Deleting an item from search history if it was there.
	NumberOfFoundListItem = Items.SearchString.ChoiceList.FindByValue(SearchString);
	While NumberOfFoundListItem <> Undefined Do
		Items.SearchString.ChoiceList.Delete(NumberOfFoundListItem);
		NumberOfFoundListItem = Items.SearchString.ChoiceList.FindByValue(SearchString);
	EndDo;
	
	// And put it on top.
	Items.SearchString.ChoiceList.Insert(0, SearchString);
	While Items.SearchString.ChoiceList.Count() > 100 Do
		Items.SearchString.ChoiceList.Delete(Items.SearchString.ChoiceList.Count() - 1);
	EndDo;
	Common.CommonSettingsStorageSave(
		"InteractionSearchHistory",
		"",
		Items.SearchString.ChoiceList.UnloadValues());
	
	CommonClientServer.SetDynamicListFilterItem(
			List,
			"Search",
			DetailsSPFound.Unload(,"Interaction").UnloadColumn("Interaction"),
			DataCompositionComparisonType.InList,, True);
			
	Items.SearchString.BackColor = StyleColors.FieldBackColor;
	Return Undefined;
	
EndFunction

&AtClient
Procedure FillDetailsSPFound(Interaction)

	DetailsString = DetailsSPFound.FindRows(New Structure("Interaction",Interaction));
	If DetailsString.Count() = 0 Then
		DetailSPFound = "";
	Else
		TableRowWithDetails = DetailsString[0];
		If InteractionsClientServer.IsAttachedInteractionsFile(TableRowWithDetails.Value) Then
			TextFound = NStr("ru = 'Найдено в присоединенном файле'; en = 'Found in the attached file'; pl = 'Znaleziono w załączonym pliku';es_ES = 'Encontrado en el archivo adjunto';es_CO = 'Encontrado en el archivo adjunto';tr = 'Ekli dosyada bulundu';it = 'Trovato nel file allegato';de = 'In der angehängten Datei gefunden'");
		Else
			TextFound = NStr("ru = 'Найдено в'; en = 'Found in'; pl = 'Znaleziono w';es_ES = 'Encontrado en';es_CO = 'Encontrado en';tr = 'Bulundu';it = 'Trovato in';de = 'Gefunden in'");
		EndIf;
		
		DetailSPFound = TextFound + " - " + TableRowWithDetails.Details;
	EndIf;

EndProcedure 

///////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

&AtServer
Function FindRowInCollectionFormData(WhereToFind, Value, Column)

	FoundRows = WhereToFind.FindRows(New Structure(Column, Value));
	If FoundRows.Count() > 0 Then
		Return FoundRows[0].GetID();
	EndIf;
	
	Return -1;
	
EndFunction

&AtServer
Function FindStringInFormDataTree(WhereToFind, Value, Column, SearchSubordinateItems)
	
	TreeItems = WhereToFind.GetItems();
	
	For each TreeItem In TreeItems Do
		If TreeItem[Column] = Value Then
			Return TreeItem.GetID();
		ElsIf  SearchSubordinateItems Then
			FoundRowID =  FindStringInFormDataTree(TreeItem, Value,Column, SearchSubordinateItems);
			If FoundRowID >=0 Then
				Return FoundRowID;
			EndIf;
		EndIf;
	EndDo;
	
	Return -1;
	
EndFunction

&AtClient
Function CurrentItemNavigationPanelList()

	If Items.NavigationPanelPages.CurrentPage = Items.ContactPage Then
		Return Items.NavigationPanelContacts;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.SubjectPage Then
		Return Items.NavigationPanelSubjects;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.FoldersPage Then
		Return Items.Folders;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.PropertiesPage Then
		Return Items.Properties;
	ElsIf Items.NavigationPanelPages.CurrentPage = Items.CategoriesPage Then
		Return Items.Categories;
	Else
		Return Undefined;
	EndIf;

EndFunction

&AtClient
Function CorrectChoice(ListName, ByCurrentString = False)
	
	GroupingType = Type("DynamicListGroupRow");
	If ByCurrentString Then
		
		If TypeOf(Items[ListName].CurrentRow) <> GroupingType AND Items[ListName].CurrentData <> Undefined Then
			Return True;
		EndIf;
		
	Else
		
		For Each Item In Items[ListName].SelectedRows Do
			If TypeOf(Item) <> GroupingType Then
				Return True;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return False;
	
EndFunction 

&AtServer
Procedure CopyFilter(Destination, Source, DeleteGroupPresentation = False, DeleteUnusedItems = True, DoNotEnableNavigationPanelFilter = False)
	
	For each SourceFilterItem In Source.Items Do
		
		If DeleteUnusedItems AND (Not SourceFilterItem.Use) Then
			Continue;
		EndIf;
		
		If DoNotEnableNavigationPanelFilter AND TypeOf(SourceFilterItem) = Type("DataCompositionFilterItemGroup") 
			AND SourceFilterItem.Presentation = "FIlterNavigationPanel" Then
			
			Continue;
			
		EndIf;
		
		If TypeOf(SourceFilterItem) = Type("DataCompositionFilterItem") 
			AND SourceFilterItem.LeftValue = New DataCompositionField("Search") Then
			Continue;
		EndIf;
		
		FilterItem = Destination.Items.Add(TypeOf(SourceFilterItem));
		FillPropertyValues(FilterItem, SourceFilterItem);
		If TypeOf(SourceFilterItem) = Type("DataCompositionFilterItemGroup") Then
			If DeleteGroupPresentation Then
				FilterItem.Presentation = "";
			EndIf;
			CopyFilter(FilterItem, SourceFilterItem);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure QuestionOnFolderDeletionAfterCompletion(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		
		ErrorDescription =  DeleteFolderServer(AdditionalParameters.CurrentData.Value);
		If NOT IsBlankString(ErrorDescription) Then
			ShowMessageBox(, ErrorDescription);
		Else
			RestoreExpandedTreeNodes();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessingDateChoiceOnCompletion(SelectedDate, AdditionalParameters) Export
	
	CurrentItemName = AdditionalParameters.CurrentItemName;
	
	If SelectedDate <> Undefined Then
		DeferReview(SelectedDate, ?(CurrentItemName = Undefined, Undefined, Items[CurrentItemName].SelectedRows));
		RestoreExpandedTreeNodes();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateNavigationPanelAtServer()
	
	RefreshNavigationPanel();
	ManageVisibilityOnSwitchNavigationPanel();
	
EndProcedure

&AtServer
Procedure PrepareFormSettingsForCurrentRefOutput(CurrentRef)
	CurrentNavigationPanelName = "SubjectPage";
	If InteractionsClientServer.IsSubject(CurrentRef) Then
		Topic = CurrentRef;
	ElsIf InteractionsClientServer.IsInteraction(CurrentRef) Then
		Topic = Interactions.InteractionAttributesStructure(CurrentRef).Topic;
	Else
		Topic = Undefined;
	EndIf;
	If ValueIsFilled(Topic) Then
		Items.NavigationPanelSubjects.CurrentRow = InformationRegisters.InteractionsSubjectsStates.CreateRecordKey(New Structure("Topic", Topic));
		ChangeFilterList("Subjects", New Structure("Value, TypeDescription", Topic, Undefined));
	EndIf;
EndProcedure

&AtServer
Procedure NavigationProcessingAtServer(CurrentRef)
	PrepareFormSettingsForCurrentRefOutput(CurrentRef);
	
	If SearchString <> "" Then
		SearchString = "";
		AdvancedSearch = False;
		CommonClientServer.SetDynamicListFilterItem(
			List, 
			"Search",
			Undefined,
			DataCompositionComparisonType.Equal,,False);
		Items.DetailSPFound.Visible = AdvancedSearch;
	EndIf;
	
	InteractionType = "All";
	Status = "All";
	EmployeeResponsible = Undefined;
	InteractionsClientServer.QuickFilterListOnChange(ThisObject,"EmployeeResponsible");
	OnChangeTypeServer(True);
	
	NavigationPanelHidden = False;
	Items.NavigationPanelPages.CurrentPage = Items[CurrentNavigationPanelName];
	ManageVisibilityOnSwitchNavigationPanel();
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		DisplayInteractionPreview(InteractionPreviewGeneratedFor, Items.PagesPreview.CurrentPage.Name);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure SetSecurityWarningVisiblity(Form)
	Form.Items.SecurityWarning.Visible = Not Form.UnsafeContentDisplayInEmailsProhibited
		AND Form.HasUnsafeContent AND Not Form.EnableUnsafeContent;
EndProcedure

#EndRegion
