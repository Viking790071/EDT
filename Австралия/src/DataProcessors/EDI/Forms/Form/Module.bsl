
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetEDIProviderValue();
	
	StateToBeSent = NStr("en = 'To be sent'; ru = 'Для отправки';pl = 'Do wysłania';es_ES = 'Para enviar';es_CO = 'Para enviar';tr = 'Gönderilecek';it = 'Da inviare';de = 'Zu senden'");
	StateSent = NStr("en = 'Sent'; ru = 'Отправлено';pl = 'Wysłano';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönderildi';it = 'Inviato';de = 'Gesendet'");
	StateFinalized = NStr("en = 'Completed'; ru = 'Завершено';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'");
	
	FillActionsTree();
	OutgoingDocuments.Parameters.SetParameterValue("Provider", EDIProvider);
	OutgoingDocuments.Parameters.SetParameterValue("StateToBeSent", StateToBeSent);
	OutgoingDocuments.Parameters.SetParameterValue("StateSent", StateSent);
	OutgoingDocuments.Parameters.SetParameterValue("StateFinalized", StateFinalized);
	
	EDIServer.PostCommandsToForm(ThisObject, Items.EDIExchange, False);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshEDIState" Then
		
		Items.OutgoingDocuments.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EDIProviderOnChange(Item)
	
	FormManagement();
	FillActionsTree();
	OutgoingDocuments.Parameters.SetParameterValue("Provider", EDIProvider);
	
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(OutgoingDocuments, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)
	
	DriveClientServer.SetListFilterItem(OutgoingDocuments, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(OutgoingDocuments, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(OutgoingDocuments, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

#EndRegion

#Region ActionsFormTableItemsEventHandlers

&AtClient
Procedure ActionsOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	NewAction = Item.CurrentData.Value;
	If NewAction <> CurrentAction Then
		OnActionChange(NewAction);
	EndIf;
	
EndProcedure

#EndRegion

#Region OutgoingDocumentsFormTableItemsEventHandlers

&AtClient
Procedure OutgoingDocumentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Items.OutgoingDocuments.RowData(SelectedRow).Ref);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetEDIProviderValue()
	
	EDIProviders = Enums.EDIProviders;
	
	If EDIProviders.Count() = 1 Then
		
		EDIProvider = EDIProviders[0];
		Items.EDIProvider.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillActionsTree()
	
	ActionsTree = FormAttributeToValue("Actions");
	
	ActionsTree.Rows.Clear();
	
	ToBeSentRow = ActionsTree.Rows.Add();
	ToBeSentRow.Value = StateToBeSent;
	
	SentRow = ActionsTree.Rows.Add();
	SentRow.Value = StateSent;
	
	FinalizedRow = ActionsTree.Rows.Add();
	FinalizedRow.Value = StateFinalized;
	
	If ValueIsFilled(EDIProvider) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	EDocumentStatuses.Description AS Description,
		|	EDocumentStatuses.IsFinal AS IsFinal
		|FROM
		|	Catalog.EDocumentStatuses AS EDocumentStatuses
		|WHERE
		|	NOT EDocumentStatuses.DeletionMark
		|	AND EDocumentStatuses.Parent = &Provider";
		
		Query.SetParameter("Provider", ProviderEDocumentFolder(EDIProvider));
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If ValueIsFilled(SelectionDetailRecords.IsFinal) Then
				
				NewRow = FinalizedRow.Rows.Add();
				NewRow.Value = SelectionDetailRecords.Description;
				
			Else
				
				NewRow = SentRow.Rows.Add();
				NewRow.Value = SelectionDetailRecords.Description;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ValueToFormAttribute(ActionsTree, "Actions");
	
EndProcedure

&AtServerNoContext
Function ProviderEDocumentFolder(Provider)
	
	Result = Catalogs.EDocumentStatuses.EmptyRef();
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	EDocumentStatuses.Ref AS Ref
	|FROM
	|	Catalog.EDocumentStatuses AS EDocumentStatuses
	|WHERE
	|	EDocumentStatuses.IsFolder
	|	AND EDocumentStatuses.Predefined
	|	AND EDocumentStatuses.Description = &Description";
	
	Query.SetParameter("Description", XMLString(Provider));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Result = SelectionDetailRecords.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FormManagement()
	
	Items.WorkingArea.Enabled = ValueIsFilled(EDIProvider);
	
EndProcedure

&AtClient
Procedure OnActionChange(Val NewAction)
	
	If ValueIsFilled(NewAction) Then
		
		If NewAction = StateToBeSent
			Or NewAction = StateSent
			Or NewAction = StateFinalized Then
			
			DriveClientServer.DeleteListFilterItem(OutgoingDocuments, "Status");
			DriveClientServer.SetListFilterItem(OutgoingDocuments, "State", NewAction);
			
		Else
			
			DriveClientServer.DeleteListFilterItem(OutgoingDocuments, "State");
			DriveClientServer.SetListFilterItem(OutgoingDocuments, "Status", NewAction);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Integration.EDI

&AtClient
Procedure Attachable_EDIExecuteCommand(Command)
	
	DocumentsArray = New Array;
	
	For Each SelectedRow In Items.OutgoingDocuments.SelectedRows Do
		
		DocumentsArray.Add(Items.OutgoingDocuments.RowData(SelectedRow).Ref);
		
	EndDo;
	
	If Items.OutgoingDocuments.CurrentData <> Undefined Then
	
		EDIClient.EDIExecuteCommand(Command, ThisObject, DocumentsArray);
	
	EndIf;
	
EndProcedure

// End Integration.EDI

#EndRegion