
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseWorkOrders" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "SettingsWorkOrders", "Enabled", ConstantsSet.UseWorkOrders);
		
		If ConstantsSet.UseWorkOrders Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"CatalogWorkOrderStates",
				"Enabled",
				ConstantsSet.UseWorkOrderStatuses);
			CommonClientServer.SetFormItemProperty(Items,
				"SettingWorkOrderStatesDefault",
				"Enabled",
				Not ConstantsSet.UseWorkOrderStatuses);
			
		EndIf;
		
	EndIf;
	
	If RunMode.IsSystemAdministrator And ConstantsSet.UseWorkOrders Then
		
		If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Or AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"CatalogWorkOrderStates",
				"Enabled",
				ConstantsSet.UseWorkOrderStatuses);
			CommonClientServer.SetFormItemProperty(Items,
				"SettingWorkOrderStatesDefault",
				"Enabled",
				Not ConstantsSet.UseWorkOrderStatuses);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses Then
			
			If Not ValueIsFilled(ConstantsSet.WorkOrdersInProgressStatus)
				Or Not ValueIsFilled(ConstantsSet.StateCompletedWorkOrders) Then
				
				UpdateWorkOrderStatesOnChange();
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseWorkOrders" Then
		
		ConstantsSet.UseWorkOrders = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		ConstantsSet.UseWorkOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.WorkOrdersInProgressStatus" Then
		
		ConstantsSet.WorkOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedWorkOrders" Then
		
		ConstantsSet.StateCompletedWorkOrders = CurrentValue;
		
	EndIf;
	
EndProcedure

// Procedure to control the clearing of the "Use work" check box.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseWorkSubsystem()
	
	ErrorText = "";
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseWorkOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseWorkOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	WorkOrder.Ref AS Ref
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|WHERE
	|	(WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT WorkOrder.Closed)";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Work orders. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Open"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для заказ-нарядов. Чтобы снять флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт""
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт) измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można oczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla zleceń pracy. Aby móc oczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de trabajo. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de trabajo. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|İş emirleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu emirlerin durumlarını değiştirin.
			|""Açık"" durumundaki emirlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki emirlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için emirleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono già impostati per gli Ordini di lavoro. Per poter deselezionare la casella di controllo,
			|modificare gli stati di questi ordini. Per gli ordini con stato ""Aperto"",
			|modificare lo stato in ""In lavorazione"" o ""Completato"" (chiuso).
			|Per gli ordini con stato ""Completato"" (non chiuso), modificare lo stato in ""Completato"" (chiuso).
			|Per fare ciò, chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Arbeitsaufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServerNoContext
Procedure UpdateWorkOrderStatesOnChange()
	
	InProcessStatus = Constants.WorkOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedWorkOrders.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	WorkOrderStatuses.Ref AS State
		|FROM
		|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|WHERE
		|	WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.WorkOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	WorkOrderStatuses.Ref AS State
		|FROM
		|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|WHERE
		|	WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.StateCompletedWorkOrders.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Disable/disable the Service section
	If AttributePathToData = "ConstantsSet.UseWorkOrders" Then
		
		If Constants.UseWorkOrders.Get() <> ConstantsSet.UseWorkOrders
			AND (NOT ConstantsSet.UseWorkOrders) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseWorkSubsystem();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are Work orders with the status which differs from Completed, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		If Constants.UseWorkOrderStatuses.Get() <> ConstantsSet.UseWorkOrderStatuses
			And Not ConstantsSet.UseWorkOrderStatuses Then
			
			ErrorText = CancellationUncheckUseWorkOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the WorkOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.WorkOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses
			And Not ValueIsFilled(ConstantsSet.WorkOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = '""In progress"" status is required.'; ru = 'Требуется статус ""В работе"".';pl = 'Wymagany jest status ""W toku"".';es_ES = 'Se requiere el estado ""En progreso"".';es_CO = 'Se requiere el estado ""En progreso"".';tr = '""İşlemde"" durumu gerekli.';it = 'Richiesto lo stato ""In corso"".';de = 'Status ""In Bearbeitung"" ist erforderlich.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.WorkOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedWorkOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedWorkOrders" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses
			And Not ValueIsFilled(ConstantsSet.StateCompletedWorkOrders) Then
			
			ErrorText = NStr("en = '""Completed"" status is required.'; ru = 'Требуется статус ""Завершен"".';pl = 'Wymagany jest status ""Zakończono"".';es_ES = 'Se requiere el estado ""Finalizado"".';es_CO = 'Se requiere el estado ""Finalizado"".';tr = '""Tamamlandı"" durumu gerekli.';it = 'Richiesto lo stato ""Completato"".';de = 'Status ""Abgeschlossen"" ist erforderlich.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedWorkOrders.Get());
			
		EndIf;
		
	EndIf;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CatalogWorkOrderStates.
//
&AtClient
Procedure CatalogWorkOrderStates(Command)
	
	OpenForm("Catalog.WorkOrderStatuses.ListForm");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonCached.ApplicationRunMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the UseWorkOrders field.
//
&AtClient
Procedure FunctionalOptionUseWorkSubsystemOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseWorkOrderStates field.
//
&AtClient
Procedure UseWorkOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CompletedStatus field.
//
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion