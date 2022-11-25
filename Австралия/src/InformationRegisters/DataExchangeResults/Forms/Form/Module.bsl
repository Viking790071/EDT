
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		
		Items.UnpostedDocumentsContextMenu.ChildItems.UnpostedDocumentsContextMenuEditSelectedDocuments.Visible = False;
		Items.UnpostedDocumentsEditSelectedDocuments.Visible = False;
		Items.BlankAttributesContextMenu.ChildItems.BlankAttributesContextMenuEditSelectedObjects.Visible = False;
		Items.BlankAttributesEditSelectedObjects.Visible = False;
		
	EndIf;
	
	PeriodClosingDatesEnabled = 
		Common.SubsystemExists("StandardSubsystems.PeriodClosingDates");
	
	VersioningUsed = DataExchangeCached.VersioningUsed(, True);
	If VersioningUsed Then
		
		ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
		ModuleObjectVersioning.InitializeDynamicListOfCorruptedVersions(Conflicts, "Conflicts");
		
		If PeriodClosingDatesEnabled Then
			ModuleObjectVersioning.InitializeDynamicListOfCorruptedVersions(RejectedDueToDate, "RejectedDueToDate");
		EndIf;
	EndIf;
	
	Items.ConflictPage.Visible = VersioningUsed;
	Items.RejectedByRestrictionDatePage.Visible = VersioningUsed AND PeriodClosingDatesEnabled;
	
	// Setting filters of dynamic lists and saving them in the attribute to manage them.
	SetUpDynamicListFilters(DynamicListsFiltersSettings);
	
	If Common.DataSeparationEnabled() AND VersioningUsed Then
		
		Items.ConflictsAnotherVersionAuthor.Title = NStr("ru = 'Версия получена из приложения'; en = 'Version is received from the application'; pl = 'Wersja pobrana z aplikacji';es_ES = 'Versión se ha recibido de la aplicación';es_CO = 'Versión se ha recibido de la aplicación';tr = 'Sürüm, uygulamadan alındı';it = 'La versione viene ricevuto dall''applicazione';de = 'Version wird von der Anwendung erhalten'");
		
	EndIf;
	
	FillNodeList();
	
	UpdateFiltersAndIgnored();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	Notify("DataExchangeResultFormClosed");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	UpdateAtServer();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	UpdateFiltersAndIgnored();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	UpdateFilterByReason();
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	UpdateFilterByPeriod();
	
EndProcedure

&AtClient
Procedure InfobaseNodeClearing(Item, StandardProcessing)
	
	InfobaseNode = Undefined;
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeOnChange(Item)
	
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InfobaseNode.ListChoiceMode Then
		
		StandardProcessing = False;
		
		Handler = New NotifyDescription("InfobaseNodeStartChoiceCompletion", ThisObject);
		Mode = FormWindowOpeningMode.LockOwnerWindow;
		OpenForm("CommonForm.SelectExchangePlanNodes",,,,,, Handler, Mode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoiceCompletion(ClosingResult, AdditionalParameters) Export
	
	InfobaseNode = ClosingResult;
	
	UpdateFilterByNode();
	
EndProcedure

&AtClient
Procedure InfobaseNodeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InfobaseNode = ValueSelected;
	
EndProcedure

&AtClient
Procedure DataExchangeResultsOnCurrentPageChange(Item, CurrentPage)
	
	If Item.ChildItems.ConflictPage = CurrentPage Then
		Items.SearchString.Enabled = False;
	Else
		Items.SearchString.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region UnpostedDocumentsFormTableItemsEventHandlers

&AtClient
Procedure UnpostedDocumentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure UnpostedDocumentsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region BlankAttributesFormTableItemsEventHandlers

&AtClient
Procedure BlankAttributesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure BlankAttributesBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ConflictsBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ConflictsOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.OtherVersionAccepted Then
			
			ConflictReason = NStr("ru = 'Конфликт был разрешен автоматически в пользу программы ""%1"".
				|Версия в этой программе была заменена на версию из другой программы.'; 
				|en = 'The conflict was automatically resolved for application ""%1"". 
				|This application version was replaced with the version of another application.'; 
				|pl = 'Konflikt został rozwiązany automatycznie na korzyść aplikacji ""%1"".
				|Wersja tej aplikacji została zmieniona na wersję z innej aplikacji.';
				|es_ES = 'Conflicto se ha permitido automáticamente a favor de la aplicación ""%1"".
				|Versión en esta aplicación se ha cambiado a la versión de otra aplicación.';
				|es_CO = 'Conflicto se ha permitido automáticamente a favor de la aplicación ""%1"".
				|Versión en esta aplicación se ha cambiado a la versión de otra aplicación.';
				|tr = '""%1"" uygulaması için uyuşmazlık otomatik olarak çözüldü. 
				|Bu uygulama sürümü, başka bir uygulamanın sürümüyle değiştirildi.';
				|it = 'Il conflitto è stato risolto automaticamente a favore dell''applicazione ""%1"".
				|Questa versione dell''applicazione è stata sostituita con la versione dell''altra applicazione.';
				|de = 'Konflikt wurde automatisch zugunsten der Anwendung ""%1"" erlaubt.
				|Version in dieser Anwendung wurde von einer anderen Anwendung in Version geändert.'");
			ConflictReason = StringFunctionsClientServer.SubstituteParametersToString(ConflictReason, Item.CurrentData.OtherVersionAuthor);
			
		Else
			
			ConflictReason =NStr("ru = 'Конфликт был разрешен автоматически в пользу этой программы.
				|Версия в этой программе была сохранена, версия из другой программы была отклонена.'; 
				|en = 'The conflict was automatically resolved for this application.
				|This application version was saved, the other application version was rejected.'; 
				|pl = 'Konflikt został rozwiązany automatycznie na korzyść danej aplikacji.
				|Wersja w tej aplikacji została zapisana, wersja z innej aplikacji została odrzucona.';
				|es_ES = 'Conflicto se ha permitido automáticamente a favor de esta aplicación.
				|Versión en esta aplicación se ha guardado, la versión de otra aplicación se ha rechazado.';
				|es_CO = 'Conflicto se ha permitido automáticamente a favor de esta aplicación.
				|Versión en esta aplicación se ha guardado, la versión de otra aplicación se ha rechazado.';
				|tr = 'Bu uygulama için uyuşmazlık otomatik çözüldü.
				|Bu uygulama sürümü kaydedildi, diğer uygulama sürümü reddedildi.';
				|it = 'Il conflitto è stato risolto automaticamente a favore di questa applicazione.
				|Questa versione dell''applicazione è stata salvata, mentre l''altra versione dell''applicazione è stata respinta.';
				|de = 'Der Konflikt wurde automatisch zugunsten dieser Anwendung zugelassen.
				|Version in dieser Anwendung wurde gespeichert, Version von einer anderen Anwendung wurde abgelehnt.'");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeclinedByDateBeforeRowChange(Item, Cancel)
	
	ObjectChange();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure DeclinedByDateOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.NewObject Then
			
			Items.DeclinedByDateAcceptVersion.Enabled = False;
			
		Else
			
			Items.DeclinedByDateAcceptVersion.Enabled = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	
	ObjectChange();
	
EndProcedure

&AtClient
Procedure IgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, True, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure DoNotIgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, False, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure DoNotIgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, False, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure IgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, True, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure EditSelectedDocuments(Command)
	
	ChangeSelectedItems(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure Update(Command)
	
	UpdateAtServer();
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	ClearMessages();
	PostDocuments(Items.UnpostedDocuments.SelectedRows);
	UpdateAtServer("UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure EditSelectedObjects(Command)
	
	ChangeSelectedItems(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure ShowDifferencesRejectedItems(Command)
	
	ShowDifferences(Items.RejectedDueToDate);
	
EndProcedure

&AtClient
Procedure OpenVersionDeclined(Command)
	
	If Items.RejectedDueToDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(Items.RejectedDueToDate.CurrentData.OtherVersionNumber);
	OpenVersionComparisonReport(Items.RejectedDueToDate.CurrentData.Ref, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenVersionDeclinedInThisApplication(Command)
	
	If Items.RejectedDueToDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(Items.RejectedDueToDate.CurrentData.ThisVersionNumber);
	OpenVersionComparisonReport(Items.RejectedDueToDate.CurrentData.Ref, VersionsToCompare);

EndProcedure

&AtClient
Procedure ShowDifferencesConflicts(Command)
	
	ShowDifferences(Items.Conflicts);
	
EndProcedure

&AtClient
Procedure IgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, True, "Conflicts");
	
EndProcedure

&AtClient
Procedure IgnoreDeclined(Command)
	
	IgnoreVersion(Items.RejectedDueToDate.SelectedRows, True, "RejectedDueToDate");
	
EndProcedure

&AtClient
Procedure DoNotIgnoreConflict(Command)
	
	IgnoreVersion(Items.Conflicts.SelectedRows, False, "Conflicts");
	
EndProcedure

&AtClient
Procedure DoNotIgnoreDeclined(Command)
	
	IgnoreVersion(Items.RejectedDueToDate.SelectedRows, False, "RejectedDueToDate");
	
EndProcedure

&AtClient
Procedure AcceptVersionDeclined(Command)
	
	NotifyDescription = New NotifyDescription("AcceptVersionNotAcceptedCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Принять версию, несмотря на запрет загрузки?'; en = 'Do you want to accept the version even though import is restricted?'; pl = 'Zaakceptować wersję pomimo zakazu importu danych?';es_ES = '¿Aceptar la versión a pesar de la prohibición de la importación?';es_CO = '¿Aceptar la versión a pesar de la prohibición de la importación?';tr = 'İçe aktarma yasağına rağmen sürümü kabul etmek istiyor musunuz?';it = 'Accettare la versione nonostante le limitazioni dell''importazione?';de = 'Version akzeptieren trotz Importverbot?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure AcceptVersionNotAcceptedCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		AcceptRejectVersionAtServer(Items.RejectedDueToDate.SelectedRows, "RejectedDueToDate");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPreConflictVersion(Command)
	
	CurrentData = Items.Conflicts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	OpenVersionAtClient(Items.Conflicts.CurrentData, CurrentData.ThisVersionNumber);
	
EndProcedure

&AtClient
Procedure OpenConflictVersion(Command)
	
	CurrentData = Items.Conflicts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	OpenVersionAtClient(Items.Conflicts.CurrentData, CurrentData.OtherVersionNumber);
	
EndProcedure

&AtClient
Procedure ShowIgnoredConflicts(Command)
	
	ShowIgnoredConflicts = Not ShowIgnoredConflicts;
	ShowIgnoredConflictsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredBlankItems(Command)
	
	ShowIgnoredBlankItems = Not ShowIgnoredBlankItems;
	ShowIgnoredBlankItemsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredRejectedItems(Command)
	
	ShowIgnoredRejectedItems = Not ShowIgnoredRejectedItems;
	ShowIgnoredRejectedItemsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredUnpostedItems(Command)
	
	ShowIgnoredUnpostedItems = Not ShowIgnoredUnpostedItems;
	ShowIgnoredUnpostedItemsAtServer();
	
EndProcedure

&AtClient
Procedure ChangeConflictResult(Command)
	
	If Items.Conflicts.CurrentData <> Undefined Then
		
		If Items.Conflicts.CurrentData.OtherVersionAccepted Then
			
			QuestionText = NStr("ru = 'Заменить версию, полученную из другой программы, на версию из этой программы?'; en = 'Do you want to replace the object version from another application with the object version from this application?'; pl = 'Zamienić wersję pobraną z innej aplikacji na wersję z danej aplikacji?';es_ES = '¿Reemplazar la versión recibida de otra aplicación con la versión de esta aplicación?';es_CO = '¿Reemplazar la versión recibida de otra aplicación con la versión de esta aplicación?';tr = 'Başka bir uygulamadan alınan sürüm bu uygulamanın sürümü ile değiştirilsin mi?';it = 'Vuoi sostituire la versione dell''oggetto da un''altra applicazione con la versione dell''oggetto da questa applicazione?';de = 'Ersetzen Sie die von einer anderen Anwendung erhaltene Version durch die Version dieser Anwendung?'");
			
		Else
			
			QuestionText = NStr("ru = 'Заменить версию этой программы на версию, полученную из другой программы?'; en = 'Do you want to replace the object version from this application with the object version from another application?'; pl = 'Zamienić wersję z danej aplikacji na wersję pobraną z innej aplikacji?';es_ES = '¿Reemplazar una versión de esta aplicación con la versión recibida de otra aplicación?';es_CO = '¿Reemplazar una versión de esta aplicación con la versión recibida de otra aplicación?';tr = 'Bu uygulamanın bir sürümü başka bir uygulamadan alınan sürümle değiştirilsin mi?';it = 'Vuoi sostituire la versione dell''oggetto da questa applicazione con la versione dell''oggetto da un''altra applicazione?';de = 'Ersetzen Sie eine Version dieser Anwendung durch die von einer anderen Anwendung erhaltene Version?'");
			
		EndIf;
		
		NotifyDescription = New NotifyDescription("ChangeConflictResultCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeConflictResultCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		AcceptRejectVersionAtServer(Items.Conflicts.SelectedRows, "Conflicts");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure Ignore(Val SelectedRows, Ignore, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
	
		InformationRegisters.DataExchangeResults.Ignore(SelectedRow.ObjectWithIssue, SelectedRow.IssueType, Ignore);
	
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure


&AtServer
Procedure ShowIgnoredConflictsAtServer(Update = True)
	
	Items.ConflictsShowIgnoredConflicts.Check = ShowIgnoredConflicts;
	
	Filter = Conflicts.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFiltersSettings.Conflicts.VersionIgnored );
	FilterItem.RightValue = ShowIgnoredConflicts;
	FilterItem.Use  = Not ShowIgnoredConflicts;
	
	If Update Then
		UpdateAtServer("Conflicts");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredBlankItemsAtServer(Update = True)
	
	Items.BlankAttributesShowIgnoredBlankItems.Check = ShowIgnoredBlankItems;
	
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFiltersSettings.BlankAttributes.Skipped );
	FilterItem.RightValue = ShowIgnoredBlankItems;
	FilterItem.Use  = Not ShowIgnoredBlankItems;
	
	If Update Then
		UpdateAtServer("BlankAttributes");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredRejectedItemsAtServer(Update = True)
	
	Items.DeclinedByDateShowIgnoredDeclinedItems.Check = ShowIgnoredRejectedItems;
	
	Filter = RejectedDueToDate.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFiltersSettings.RejectedDueToDate.VersionIgnored );
	FilterItem.RightValue = ShowIgnoredRejectedItems;
	FilterItem.Use  = Not ShowIgnoredRejectedItems;
	
	If Update Then
		UpdateAtServer("RejectedDueToDate");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredUnpostedItemsAtServer(Update = True)
	
	Items.UnpostedDocumentsShowIgnoredUnpostedItems.Check = ShowIgnoredUnpostedItems;
	
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFiltersSettings.UnpostedDocuments.Skipped );
	FilterItem.RightValue = ShowIgnoredUnpostedItems;
	FilterItem.Use  = Not ShowIgnoredUnpostedItems;
	
	If Update Then
		UpdateAtServer("UnpostedDocuments");
	EndIf;
	
EndProcedure


&AtClient
Procedure ChangeSelectedItems(List)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BatchEditObjects") Then
		ModuleBatchEditObjectsClient = CommonClient.CommonModule("BatchEditObjectsClient");
		ModuleBatchEditObjectsClient.ChangeSelectedItems(List);
	EndIf;
	
EndProcedure


&AtServer
Procedure PostDocuments(Val SelectedRows)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		DocumentObject = SelectedRow.ObjectWithIssue.GetObject();
		
		If DocumentObject.CheckFilling() Then
			
			DocumentObject.Write(DocumentWriteMode.Posting);
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtServer
Procedure FillNodeList()
	
	NoExchangeByRules = True;
	ContextOpening = ValueIsFilled(Parameters.ExchangeNodes);
	
	ExchangeNodes = ?(ContextOpening, Parameters.ExchangeNodes, NodeArrayOnOpenOutOfContext());
	Items.InfobaseNode.ChoiceList.LoadValues(ExchangeNodes);
	
	For Each ExchangeNode In ExchangeNodes Do
		
		If DataExchangeCached.IsUniversalDataExchangeNode(ExchangeNode) Then
			
			NoExchangeByRules = False;
			
		EndIf;
		
	EndDo;
	
	SetFilterByNodes(ExchangeNodes);
	NodesList = New ValueList;
	NodesList.LoadValues(ExchangeNodes);
	
	If ExchangeNodes.Count() < 2 Then
		
		InfobaseNode = Undefined;
		Items.InfobaseNode.Visible = False;
		Items.UnpostedDocumentsInfobaseNode.Visible = False;
		Items.BlankAttributesInfobaseNode.Visible = False;
		
		If VersioningUsed Then
			Items.ConflictsAnotherVersionAuthor.Visible = False;
			Items.DeclinedByDateAnotherVersionAuthor.Visible = False;
		EndIf;
		
	ElsIf ExchangeNodes.Count() >= 7 Then
		
		Items.InfobaseNode.ListChoiceMode = False;
		
	EndIf;
	
	If ContextOpening AND NoExchangeByRules Then
		Title = NStr("ru = 'Конфликты при синхронизации данных'; en = 'Data synchronization conflicts'; pl = 'Podczas synchronizacji danych wystąpił konflikt';es_ES = 'Conflictos durante la sincronización de datos';es_CO = 'Conflictos durante la sincronización de datos';tr = 'Veri senkronizasyonu sırasında çakışmalar';it = 'Conflitti di sincronizzazione dati';de = 'Konflikte während der Datensynchronisation'");
		Items.SearchString.Visible = False;
		Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage;
		Items.DataExchangeResults.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFilterByNodes(ExchangeNodes)
	
	FilterByNodesDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.NodeInList);
	FilterByNodesDocument.Use = True;
	FilterByNodesDocument.RightValue = ExchangeNodes;
	
	FilterByNodesObject = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.NodeInList);
	FilterByNodesObject.Use = True;
	FilterByNodesObject.RightValue = ExchangeNodes;
	
	If VersioningUsed Then
		
		FilterByNodesConflict = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.AuthorInList);
		FilterByNodesConflict.Use = True;
		FilterByNodesConflict.RightValue = ExchangeNodes;
		
		FilterByNodesNotAccepted = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.AuthorInList);
		FilterByNodesNotAccepted.Use = True;
		FilterByNodesNotAccepted.RightValue = ExchangeNodes;
		
	EndIf;
	
EndProcedure

&AtServer
Function NodeArrayOnOpenOutOfContext()
	
	ExchangeNodes = New Array;
	
	ExchangePlanList = DataExchangeCached.SSLExchangePlans();
	
	For Each ExchangePlanName In ExchangePlanList Do
		
		If Not AccessRight("Read", ExchangePlans[ExchangePlanName].EmptyRef().Metadata()) Then
			Continue;
		EndIf;	
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	ExchangePlanTable.Ref AS ExchangeNode
		|FROM
		|	&ExchangePlanTable AS ExchangePlanTable
		|WHERE
		|	NOT ExchangePlanTable.ThisNode
		|	AND ExchangePlanTable.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
		Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			ExchangeNodes.Add(Selection.ExchangeNode);
			
		EndDo;
		
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure UpdateFilterByNode(Update = True)
	
	Usage = ValueIsFilled(InfobaseNode);
	
	FilterByNodeDocument = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.NodeEqual);
	FilterByNodeDocument.Use = Usage;
	FilterByNodeDocument.RightValue = InfobaseNode;
	
	FilterByNodeObject = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.NodeEqual);
	FilterByNodeObject.Use = Usage;
	FilterByNodeObject.RightValue = InfobaseNode;
	
	If VersioningUsed Then
		
		FilterByNodeConflicts = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.AuthorEqual);
		FilterByNodeConflicts.Use = Usage;
		FilterByNodeConflicts.RightValue = InfobaseNode;
		
		FilterByNodeNotAccepted = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.AuthorEqual);
		FilterByNodeNotAccepted.Use = Usage;
		FilterByNodeNotAccepted.RightValue = InfobaseNode;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Function NotAcceptedCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	QueryOptions = DataExchangeServer.QueryParametersVersioningIssuesCount();
	
	QueryOptions.IsConflictCount      = False;
	QueryOptions.IncludingIgnored = ShowIgnoredConflicts;
	QueryOptions.Period                     = Period;
	QueryOptions.SearchString               = SearchString;
	
	Return DataExchangeServer.VersioningIssuesCount(ExchangeNodes, QueryOptions);
	
EndFunction

&AtServer
Function ConflictCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	QueryOptions = DataExchangeServer.QueryParametersVersioningIssuesCount();
	
	QueryOptions.IsConflictCount      = True;
	QueryOptions.IncludingIgnored = ShowIgnoredConflicts;
	QueryOptions.Period                     = Period;
	QueryOptions.SearchString               = SearchString;
	
	Return DataExchangeServer.VersioningIssuesCount(ExchangeNodes, QueryOptions);
	
EndFunction

&AtServer
Function BlankAttributeCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	SearchParameters = InformationRegisters.DataExchangeResults.IssueSearchParameters();
	SearchParameters.IssueType                = Enums.DataExchangeIssuesTypes.BlankAttributes;
	SearchParameters.IncludingIgnored = ShowIgnoredBlankItems;
	SearchParameters.Period                     = Period;
	SearchParameters.SearchString               = SearchString;
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(ExchangeNodes, SearchParameters);
	
EndFunction

&AtServer
Function UnpostedDocumentCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, NodesList);
	
	SearchParameters = InformationRegisters.DataExchangeResults.IssueSearchParameters();
	SearchParameters.IssueType                = Enums.DataExchangeIssuesTypes.UnpostedDocument;
	SearchParameters.IncludingIgnored = ShowIgnoredUnpostedItems;
	SearchParameters.Period                     = Period;
	SearchParameters.SearchString               = SearchString;
	
	Return InformationRegisters.DataExchangeResults.IssuesCount(ExchangeNodes, SearchParameters);
	
EndFunction

&AtServer
Procedure SetPageTitle(Page, Header, Count)
	
	AdditionalString = ?(Count > 0, " (" + Count + ")", "");
	Header = Header + AdditionalString;
	Page.Title = Header;
	
EndProcedure

&AtClient
Procedure OpenObject(Item)
	
	If Item.CurrentRow = Undefined Or TypeOf(Item.CurrentRow) = Type("DynamicListGroupRow") Then
		ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot execute the command for the specified object.'; pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut çalıştırılamaz.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	Else
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectChange()
	
	ResultPages = Items.DataExchangeResults;
	
	If ResultPages.CurrentPage = ResultPages.ChildItems.UnpostedDocumentsPage Then
		
		OpenObject(Items.UnpostedDocuments); 
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.BlankAttributesPage Then
		
		OpenObject(Items.BlankAttributes);
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.ConflictPage Then
		
		OpenObject(Items.Conflicts);
		
	ElsIf ResultPages.CurrentPage = ResultPages.ChildItems.RejectedByRestrictionDatePage Then
		
		OpenObject(Items.RejectedDueToDate);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowDifferences(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	
	If Item.CurrentData.ThisVersionNumber <> 0 Then
		VersionsToCompare.Add(Item.CurrentData.ThisVersionNumber);
	EndIf;
	
	If Item.CurrentData.OtherVersionNumber <> 0 Then
		VersionsToCompare.Add(Item.CurrentData.OtherVersionNumber);
	EndIf;
	
	If VersionsToCompare.Count() <> 2 Then
		
		CommonClientServer.MessageToUser(NStr("ru = 'Нет версии для сравнения.'; en = 'No object version to compare.'; pl = 'Brak wersji do porównania.';es_ES = 'No hay una versión para comparar.';es_CO = 'No hay una versión para comparar.';tr = 'Karşılaştırılacak bir sürüm yok.';it = 'Nessuna versione dell''oggetto da confrontare.';de = 'Es gibt keine zu vergleichende Version.'"));
		Return;
		
	EndIf;
	
	OpenVersionComparisonReport(Item.CurrentData.Ref, VersionsToCompare);
	
EndProcedure

&AtServer
Procedure UpdateFilterByReason(Update = True)
	
	SearchStringSpecified = ValueIsFilled(SearchString);
	
	CommonClientServer.SetDynamicListFilterItem(
		UnpostedDocuments, "Reason", SearchString,DataCompositionComparisonType.BeginsWith,, SearchStringSpecified);
	
	CommonClientServer.SetDynamicListFilterItem(
		BlankAttributes, "Reason", SearchString,DataCompositionComparisonType.BeginsWith,, SearchStringSpecified);
		
	If VersioningUsed Then
	
		CommonClientServer.SetDynamicListFilterItem(
			RejectedDueToDate, "ProhibitionReason", SearchString,DataCompositionComparisonType.BeginsWith,, SearchStringSpecified);
		
	EndIf;
	
	If Update Then
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateFilterByPeriod(Update = True)
	
	Usage = ValueIsFilled(Period);
	
	// Unposted documents
	FilterByPeriodDocumentFrom = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.StartDate);
	FilterByPeriodDocumentTo = DynamicListFilterItem(UnpostedDocuments,
		DynamicListsFiltersSettings.UnpostedDocuments.EndDate);
		
	FilterByPeriodDocumentFrom.Use  = Usage;
	FilterByPeriodDocumentTo.Use = Usage;
	
	FilterByPeriodDocumentFrom.RightValue  = Period.StartDate;
	FilterByPeriodDocumentTo.RightValue = Period.EndDate;
	
	// Blank attributes
	FilterByPeriodObjectFrom = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.StartDate);
	FilterByPeriodObjectTo = DynamicListFilterItem(BlankAttributes,
		DynamicListsFiltersSettings.BlankAttributes.EndDate);
		
	FilterByPeriodObjectFrom.Use  = Usage;
	FilterByPeriodObjectTo.Use = Usage;
	
	FilterByPeriodObjectFrom.RightValue  = Period.StartDate;
	FilterByPeriodObjectTo.RightValue = Period.EndDate;
	
	If VersioningUsed Then
		
		FilterByPeriodConflictsFrom = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.StartDate);
		FilterByPeriodConflictTo = DynamicListFilterItem(Conflicts,
			DynamicListsFiltersSettings.Conflicts.EndDate);
		
		FilterByPeriodConflictsFrom.Use  = Usage;
		FilterByPeriodConflictTo.Use = Usage;
		
		FilterByPeriodConflictsFrom.RightValue  = Period.StartDate;
		FilterByPeriodConflictTo.RightValue = Period.EndDate;
		
		FilterByPeriodNotAcceptedFrom = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.StartDate);
		FilterByPeriodNotAcceptedTo = DynamicListFilterItem(RejectedDueToDate,
			DynamicListsFiltersSettings.RejectedDueToDate.EndDate);
		
		FilterByPeriodNotAcceptedFrom.Use  = Usage;
		FilterByPeriodNotAcceptedTo.Use = Usage;
		
		FilterByPeriodNotAcceptedFrom.RightValue  = Period.StartDate;
		FilterByPeriodNotAcceptedTo.RightValue = Period.EndDate;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Procedure IgnoreVersion(Val SelectedRows, Ignore, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
			ModuleObjectVersioning.IgnoreObjectVersion(SelectedRow.Object,
				SelectedRow.VersionNumber, Ignore);
		EndIf;
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure UpdateAtServer(UpdatedItem = "")
	
	UpdateFormLists(UpdatedItem);
	UpdatePageTitles();
	
EndProcedure

&AtServer
Procedure UpdateFormLists(UpdatedItem)
	
	If ValueIsFilled(UpdatedItem) Then
		
		Items[UpdatedItem].Refresh();
		
	Else
		
		Items.UnpostedDocuments.Refresh();
		Items.BlankAttributes.Refresh();
		If VersioningUsed Then
			Items.Conflicts.Refresh();
			Items.RejectedDueToDate.Refresh();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePageTitles()
	
	SetPageTitle(Items.UnpostedDocumentsPage, NStr("ru= 'Непроведенные документы'; en = 'Unposted documents'; pl = 'Niezaksięgowane dokumenty';es_ES = 'Documentos sin enviar';es_CO = 'Documentos sin enviar';tr = 'Gönderilmemiş belgeler';it = 'Documenti non pubblicati';de = 'Nicht gebuchte Dokumente'"), UnpostedDocumentCount());
	SetPageTitle(Items.BlankAttributesPage, NStr("ru= 'Незаполненные реквизиты'; en = 'Blank attributes'; pl = 'Puste atrybuty';es_ES = 'Atributos en blanco';es_CO = 'Atributos en blanco';tr = 'Doldurulmamış özellikler';it = 'Attributi vuoti';de = 'Leere Attribute'"), BlankAttributeCount());
	
	If VersioningUsed Then
		SetPageTitle(Items.ConflictPage, NStr("ru= 'Конфликты'; en = 'Conflicts'; pl = 'Konflikty';es_ES = 'Conflictos';es_CO = 'Conflictos';tr = 'Uyuşmazlıklar';it = 'Conflitti';de = 'Konflikte'"), ConflictCount());
		SetPageTitle(Items.RejectedByRestrictionDatePage, NStr("ru= 'Непринятые по дате запрета'; en = 'Items rejected due to restriction date'; pl = 'Niezaakceptowane według daty zamknięcia';es_ES = 'No aceptado antes de la fecha de cierre';es_CO = 'No aceptado antes de la fecha de cierre';tr = 'Kapanış tarihine göre kabul edilmeyenler';it = 'Elementi scartati a causa di date di restrizione.';de = 'Nicht akzeptiert bis zum Sperrdatum'"), NotAcceptedCount());
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionAtClient(CurrentData, Version)
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionsToCompare = New Array;
	VersionsToCompare.Add(Version);
	OpenVersionComparisonReport(CurrentData.Ref, VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenVersionComparisonReport(Ref, VersionsToCompare)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		ModuleObjectVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
		ModuleObjectVersioningClient.OpenVersionComparisonReport(Ref, VersionsToCompare);
	EndIf;
	
EndProcedure

&AtServer
Procedure AcceptRejectVersionAtServer(Val SelectedRows, ItemName)
	
	For Each SelectedRow In SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
			ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
			ModuleObjectVersioning.OnStartUsingNewObjectVersion(SelectedRow.Object,
				SelectedRow.VersionNumber);
		EndIf;
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure SetUpDynamicListFilters(Result)
	
	Result = New Structure;
	
	// Unposted documents
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	Result.Insert("UnpostedDocuments", New Structure);
	Setting = Result.UnpostedDocuments;
	
	Setting.Insert("Skipped", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("NodeEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Setting.Insert("Reason", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Reason", DataCompositionComparisonType.Contains, Undefined, , False)));
	Setting.Insert("NodeInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	// Blank attributes
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	Result.Insert("BlankAttributes", New Structure);
	Setting = Result.BlankAttributes;
	
	Setting.Insert("Skipped", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OccurrenceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("NodeEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Setting.Insert("Reason", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Reason", DataCompositionComparisonType.Contains, Undefined, , False)));
	Setting.Insert("NodeInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	If VersioningUsed Then
		
		// Conflicts
		Filter = Conflicts.SettingsComposer.Settings.Filter;
		Result.Insert("Conflicts", New Structure);
		Setting = Result.Conflicts;
		
		Setting.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Setting.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Setting.Insert("AuthorInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
		// Items rejected due to restriction date
		Filter = RejectedDueToDate.SettingsComposer.Settings.Filter;
		Result.Insert("RejectedDueToDate", New Structure);
		Setting = Result.RejectedDueToDate;
		
		Setting.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Setting.Insert("ProhibitionReason", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "ProhibitionReason", DataCompositionComparisonType.Equal, Undefined, , False)));
		Setting.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Setting.Insert("AuthorInList", Filter.GetIDByObject(
		CommonClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DynamicListFilterItem(Val DynamicList, Val ID)
	Return DynamicList.SettingsComposer.Settings.Filter.GetObjectByID(ID);
EndFunction

&AtServer
Procedure UpdateFiltersAndIgnored()
	
	UpdateFilterByPeriod(False);
	UpdateFilterByNode(False);
	UpdateFilterByReason(False);
	
	ShowIgnoredUnpostedItemsAtServer(False);
	ShowIgnoredBlankItemsAtServer(False);
	
	If VersioningUsed Then
		
		ShowIgnoredConflictsAtServer(False);
		ShowIgnoredRejectedItemsAtServer(False);
		
	EndIf;
	
	UpdateAtServer();
	
	If Not Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.ConflictPage Then
		
		For Each Page In Items.DataExchangeResults.ChildItems Do
			
			If StrFind(Page.Title, "(") Then
				Items.DataExchangeResults.CurrentPage = Page;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// UnpostedDocuments.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UnpostedDocuments.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UnpostedDocuments.Skipped");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject,
		"UnpostedDocuments.DocumentDate",
		Items.UnpostedDocumentsDocumentDate.Name);
	
	// Conflicts.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Conflicts.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// Conflicts, other version is accepted, text color.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConflictsAnotherVersionAccepted.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.OtherVersionAccepted");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnacceptedVersion);
	
	// Conflicts, other version is accepted, text.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConflictsAnotherVersionAccepted.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Conflicts.OtherVersionNumber");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Удалена'; en = 'Deleted'; pl = 'Usunięte';es_ES = 'Borrado';es_CO = 'Borrado';tr = 'Silindi';it = 'Eliminata';de = 'Gelöscht'"));
	
	// BlankAttributes.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.BlankAttributes.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("BlankAttributes.Skipped");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// DeclinedByDate.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RejectedDueToDate.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// DeclinedByDate, Ref.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DeclinedByDateRef.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.NewObject");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Отсутствуют'; en = 'Missing'; pl = 'Brak';es_ES = 'Falta';es_CO = 'Falta';tr = 'Eksik';it = 'Mancante';de = 'Fehlt'"));
	
	// DeclinedByDate.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DeclinedByDateAnotherVersionAuthor.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RejectedDueToDate.VersionIgnored");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnacceptedVersion);
	
EndProcedure

#EndRegion
