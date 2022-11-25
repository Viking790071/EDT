
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
	
	If RunMode.IsSystemAdministrator Then
		
		If AttributePathToData = "ConstantsSet.UseSeveralWarehouses" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogBusinessUnitsWarehouses", "Enabled", ConstantsSet.UseSeveralWarehouses);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "SettingPurchaseOrderStatesDefault","Enabled", Not ConstantsSet.UsePurchaseOrderStatuses);
			CommonClientServer.SetFormItemProperty(Items, "CatalogSalesOrderStates",	"Enabled", ConstantsSet.UsePurchaseOrderStatuses);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSerialNumbers" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "UseSerialNumbersAsInventoryRecordDetails", "Enabled", ConstantsSet.UseSerialNumbers);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseTransferOrderStatuses" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogTransferOrderStates", "Enabled", ConstantsSet.UseTransferOrderStatuses);
			CommonClientServer.SetFormItemProperty(Items, "SettingTransferOrderStatesDefault","Enabled", Not ConstantsSet.UseTransferOrderStatuses);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UsePurchaseOrderApproval" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "GroupUseSeparateApproversForCompanies", "Enabled", ConstantsSet.UsePurchaseOrderApproval);
			CommonClientServer.SetFormItemProperty(Items, "GroupPurchaseOrderApproval", "Enabled", ConstantsSet.UsePurchaseOrderApproval);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSeparateApproversForCompanies" OR AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogCompanies", "Enabled", ConstantsSet.UseSeparateApproversForCompanies);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.PurchaseOrdersApprovalType" Or AttributePathToData = "" Then
			IsApproveAll = 
				ConstantsSet.PurchaseOrdersApprovalType = PredefinedValue("Enum.PurchaseOrdersApprovalTypes.ApproveAll");
			CommonClientServer.SetFormItemProperty(Items, "LimitWithoutApproval", "Enabled", Not IsApproveAll);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UsePurchaseOrderApproval"
			Or AttributePathToData = "ConstantsSet.UseSeparateApproversForCompanies"
			Or AttributePathToData = "" Then
		
			CommonClientServer.SetFormItemProperty(Items,
				"GroupApprovers",
				"Enabled",
				ConstantsSet.UsePurchaseOrderApproval
					And Not ConstantsSet.UseSeparateApproversForCompanies);
		EndIf;
				
		If AttributePathToData = "ConstantsSet.PurchaseOrdersApprovalType"
			Or AttributePathToData = "" Then
		
			ConfigureForEachCounterparty = 
				(ConstantsSet.PurchaseOrdersApprovalType = Enums.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty);

			CommonClientServer.SetFormItemProperty(Items, "ApplyPurchaseOrdersConditions", "Visible", ConfigureForEachCounterparty);
				
			CommonClientServer.SetFormItemProperty(
				Items,
				"LimitWithoutApproval",
				"Title",
				?(ConfigureForEachCounterparty, NStr("en = 'Default approval threshold'; ru = 'Лимит утверждения по умолчанию';pl = 'Domyślny próg zatwierdzenia';es_ES = 'Umbral de aprovación por defecto';es_CO = 'Umbral de aprobación por defecto';tr = 'Varsayılan onay eşiği';it = 'Soglia di approvazione predefinita';de = 'Standard-Genehmigungsgrenzwert'"), NStr("en = 'Approval threshold'; ru = 'Лимит утверждения';pl = 'Próg zatwierdzenia';es_ES = 'Umbral de aprobación';es_CO = 'Umbral de aprobación';tr = 'Onay eşiği';it = 'Soglia di approvazione';de = 'Genehmigungsgrenze'")));
		EndIf;
		
		If AttributePathToData = "" Then
			
			UseSubcontractorManufacturersValue = Constants.UseSubcontractorManufacturers.Get();
			
			CommonClientServer.SetFormItemProperty(Items,
				"CanReceiveSubcontractingServices",
				"Enabled",
				Not UseSubcontractorManufacturersValue);
			
			CommonClientServer.SetFormItemProperty(Items,
				"DecorationSubcontractorsOrders",
				"Visible",
				UseSubcontractorManufacturersValue);
				
			KitProcessing = Constants.UseKitProcessing.Get();
			UseDriveTrade = Constants.DriveTrade.Get();
			ThereAreKitProcessedDocsInBase = ThereAreKitProcessedDocsInBase();
			
			CommonClientServer.SetFormItemProperty(Items,
				"KitProcessing",
				"Visible",
				KitProcessing Or UseDriveTrade Or ThereAreKitProcessedDocsInBase);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.CanReceiveSubcontractingServices"
			Or AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"SettingsSubcontractorOrdersIssued",
				"Visible",
				ConstantsSet.CanReceiveSubcontractingServices);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSubcontractorOrderIssuedStatuses"
			Or AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"SettingSubcontractorOrderIssuedByStatus",
				"Enabled",
				Not ConstantsSet.UseSubcontractorOrderIssuedStatuses);
			
			CommonClientServer.SetFormItemProperty(Items,
				"CatalogSubcontractorOrderIssuedStatuses",
				"Enabled",
				ConstantsSet.UseSubcontractorOrderIssuedStatuses);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseKitProcessing"
			Or AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"SettingsKitOrder",
				"Visible",
				ConstantsSet.UseKitProcessing);
				
			CommonClientServer.SetFormItemProperty(Items,
				"SettingsKitProcessed",
				"Visible",
				ConstantsSet.UseKitProcessing);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseKitOrderStatuses"
			Or AttributePathToData = "" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"SettingKitOrdersByStatus",
				"Enabled",
				Not ConstantsSet.UseKitOrderStatuses);
			
			CommonClientServer.SetFormItemProperty(Items,
				"CatalogKitOrderStatuses",
				"Enabled",
				ConstantsSet.UseKitOrderStatuses);
			
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseTransferOrderStatuses" Then
		
		If Not ConstantsSet.UseTransferOrderStatuses Then
			
			If Not ValueIsFilled(ConstantsSet.TransferOrdersInProgressStatus)
				OR ValueIsFilled(ConstantsSet.StateCompletedTransferOrders) Then
				
				UpdateTransferOrderStatesOnChange();
				
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
	
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" Then
		
		ConstantsSet.UsePurchaseOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		ConstantsSet.PurchaseOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersCompletionStatus" Then
		
		ConstantsSet.PurchaseOrdersCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseTransferOrderStatuses" Then
		
		ConstantsSet.UseTransferOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.TransferOrdersInProgressStatus" Then
		
		ConstantsSet.TransferOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedTransferOrders" Then
		
		ConstantsSet.StateCompletedTransferOrders = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralWarehouses" Then
		
		ConstantsSet.UseSeveralWarehouses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralUnitsForProduct" Then
		
		ConstantsSet.UseSeveralUnitsForProduct = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseStorageBins" Then
		
		ConstantsSet.UseStorageBins = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseCharacteristics" Then
		
		ConstantsSet.UseCharacteristics = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseBatches" Then
		
		ConstantsSet.UseBatches = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSerialNumbers" Then
		
		ConstantsSet.UseSerialNumbers = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSerialNumbersAsInventoryRecordDetails" Then
		
		ConstantsSet.UseSerialNumbersAsInventoryRecordDetails = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractorManufacturers" Then
		
		ConstantsSet.UseSubcontractorManufacturers = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseDiscountsInPurchases" Then
		
		ConstantsSet.UseDiscountsInPurchases = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UsePurchaseOrderApproval" Then
		
		ConstantsSet.UsePurchaseOrderApproval = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseAccountPayableAdjustments" Then
		
		ConstantsSet.UseAccountPayableAdjustments = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseZeroInvoicePurchases" Then
		
		ConstantsSet.UseZeroInvoicePurchases = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseKitProcessing" Then
		
		ConstantsSet.UseKitProcessing = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseByProductsInKitProcessing" Then
		
		ConstantsSet.UseByProductsInKitProcessing = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseKitOrderStatuses" Then
		
		ConstantsSet.UseKitOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.KitOrdersInProgressStatus" Then
		
		ConstantsSet.KitOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.KitOrdersCompletionStatus" Then
		
		ConstantsSet.KitOrdersCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CanReceiveSubcontractingServices" Then
		
		ConstantsSet.CanReceiveSubcontractingServices = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractorOrderIssuedStatuses" Then
	
		ConstantsSet.UseSubcontractorOrderIssuedStatuses = CurrentValue;
		
	EndIf;
	
EndProcedure

// Checks whether it is possible to clear the UsePurchaseOrderStatuses option.
//
&AtServer
Function CancellationUncheckUsePurchaseOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	PurchaseOrder.Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	(PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT PurchaseOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'To disable ""Multiple statuses"" all Purchase orders should either have a status where system behavior defined as ""Start the flow"" 
								|or should be closed by pressing ""Close orders"" button in the list of Purchase orders.'; 
								|ru = 'Чтобы отключить опцию ""Множественные статусы"", все заказы поставщику должны либо иметь статус, который определяется системой как ""Начало процесса"", 
								| либо должны быть закрыты с помощью команды ""Закрыть заказы"" в форме списка заказов поставщику.';
								|pl = 'Aby wyłączyć ""Wiele statusów"", wszystkie zamówienia zakupu powinny mieć status, w którym zachowanie systemu zdefiniowane jest, jako ""Rozpocznij przepływ""
								|albo powinno zostać zamknięte przez naciśnięcie przycisku ""Zamknij zamówienia"" na liście zamówień zakupu.';
								|es_ES = 'Para desactivar ""Múltiples estados"" todas las Órdenes de compra deben tener un estado donde el comportamiento del sistema se define como ""Iniciar el flujo"" 
								|o deben cerrarse pulsando el botón ""Cerrar órdenes"" en la lista de Órdenes de compra.';
								|es_CO = 'Para desactivar ""Múltiples estados"" todas las Órdenes de compra deben tener un estado donde el comportamiento del sistema se define como ""Iniciar el flujo"" 
								|o deben cerrarse pulsando el botón ""Cerrar órdenes"" en la lista de Órdenes de compra.';
								|tr = '""Birden fazla durum"" u devre dışı bırakmak için tüm Satın alma siparişleri ya ""Akışı başlat"" olarak tanımlanan sistem davranışının bulunduğu bir duruma sahip olmalı
								|ya da Satın alma siparişleri listesindeki ""Siparişleri kapat"" düğmesine basarak kapatılmalıdır.';
								|it = 'Per disabilitare ""Stati multipli"" tutti gli ordini di acquisto dovrebbero dovrebbero avere uno stato dove il comportamento è definito come ""Inizia il flusso""
								|o dovrebbero essere chiusi premendo il pulsante ""Chiudi ordini"" nell''elenco Ordini di acquisto.';
								|de = 'Um ""Mehrere Status"" zu deaktivieren, sollten alle Bestellungen entweder einen Status haben, in dem das Systemverhalten als ""Start den Ablauf"" definiert ist 
								| oder durch Klicken auf der Schaltfläche ""Aufträge schließen"" in der Liste der Bestellungen geschlossen werden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseTransferOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseTransferOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TransferOrder.Ref AS Ref
	|FROM
	|	Document.TransferOrder AS TransferOrder
	|WHERE
	|	(TransferOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR TransferOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT TransferOrder.Closed
	|				AND (TransferOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForSale)
	|					OR TransferOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)))";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Transfer order. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Open"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для заказа на перемещение. Чтобы снять флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт""
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт) измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można oczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla zleceń przemieszczenia. Aby móc oczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para la orden de transferencia. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para la orden de transferencia. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Transfer emri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu emirlerin durumlarını değiştirin.
			|""Açık"" durumundaki emirlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki emirlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için emirleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completo"" (non chiuso)
			| sono già impostati per l''Ordine di trasferimento. Per poter deselezionare la casella di controllo, 
			|modificare lo stato di questi ordini. Per ordini con stato ""Aperto"", 
			|modificare lo stato in ""In lavorazione"" o ""Completato"" (chiuso). 
			|Per ordini con stato ""Completato"" (non chiuso), modificare lo stato in ""Completato"" (chiuso). 
			|Per fare ciò, chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Transportaufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseSeveralWarehouses option.
//
&AtServer
Function CancellationUncheckAccountingBySeveralWarehouses()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckAccountingBySeveralWarehouses();
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear AccountingInVariousUOMs option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingInVariousUOM()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionAccountingInVariousUOM();
	
	Return ErrorText;
	
EndFunction

// Check for the option to uncheck UseSerialNumbers.
//
&AtServer
Function CancelRemoveFunctionalOptionUseSerialNumbers() Export
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SerialNumbers.SerialNumber AS SerialNumber
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SerialNumbersInWarranty.SerialNumber AS SerialNumber
	|FROM
	|	InformationRegister.SerialNumbersInWarranty AS SerialNumbersInWarranty";
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[0].IsEmpty() Or Not QueryResult[1].IsEmpty() Then
		ErrorText = NStr("en = 'You cannot disable ""Serial numbers"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Серийные номера"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Numer seryjny"".';es_ES = 'No se puede desactivar ""Números de serie"" una vez utilizado.';es_CO = 'No se puede desactivar ""Números de serie"" una vez utilizado.';tr = '""Seri numaraları"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Numeri di serie"" una volta utilizzati.';de = 'Sie können die einmal verwendeten ""Seriennummern"" nicht mehr deaktivieren.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancelChangeUseSerialNumbersAsInventoryRecordDetails(Disable = True)
	
	ErrorText = "";
	Query = New Query;
	
	If Disable Then
		
		Query.Text =
		"SELECT TOP 1
		|	SerialNumbers.SerialNumber AS SerialNumber
		|FROM
		|	AccumulationRegister.SerialNumbers AS SerialNumbers
		|WHERE
		|	SerialNumbers.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)";
		
	Else
		
		Query.Text =
		"SELECT TOP 1
		|	SerialNumbersInWarranty.SerialNumber AS SerialNumber
		|FROM
		|	InformationRegister.SerialNumbersInWarranty AS SerialNumbersInWarranty";
		
	EndIf;
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		If Disable Then
			ErrorText = NStr("en = 'You cannot disable ""Use serial numbers as inventory record details"".
				|There are entries in the register ""Serial numbers"".'; 
				|ru = 'Не удается отключить опцию ""Контроль остатков по серийным номерам"".
				|В регистре накопления ""Серийные номера"" есть проводки.';
				|pl = 'Nie można wyłączyć ""Użycie numerów seryjnych jako szczegółów wpisu zapasów"".
				|Są wpisy w rejestrze ""Numery seryjne"".';
				|es_ES = 'No se puede desactivar ""Utilizar los números de serie como detalles del registro del inventario"".
				|Hay entradas de diario en el registro ""Números de serie"".';
				|es_CO = 'No se puede desactivar ""Utilizar los números de serie como detalles del registro del inventario"".
				|Hay entradas en el registro ""Números de serie"".';
				|tr = '""Stok kayıt detayları olarak seri numaraları kullan"" seçeneği devre dışı bırakılamıyor.
				|""Seri numaraları"" kaydında girişler mevcut.';
				|it = 'Impossibile disattivare ""Controllo scorte secondo numero di serie"".
				|Ci sono inserimenti nel registro ""Numeri di serie"".';
				|de = 'Sie können ""Seriennummern als Bestandsdetails verwenden"" nicht deaktivieren.
				|Es gibt Einträge im Register ""Seriennummern"".'");
		Else
			ErrorText = NStr("en = 'You cannot enable ""Use serial numbers as inventory record details"".
				|There are entries in the register ""Serial numbers in warranty"".'; 
				|ru = 'Не удается включить опцию ""Контроль остатков по серийным номерам"".
				|В регистре сведений ""Серийные номера на гарантии"" есть проводки.';
				|pl = 'Nie można włączyć ""Użycie numerów seryjnych jako szczegółów wpisu zapasów"".
				|Istnieją wpisy w rejestrze ""Numery seryjne w gwarancji"".';
				|es_ES = 'No se puede activar ""Utilizar los números de serie como detalles del registro del inventario"".
				|Hay entradas de diario en el registro ""Números de serie en garantía"".';
				|es_CO = 'No se puede activar ""Utilizar los números de serie como detalles del registro del inventario"".
				|Hay entradas en el registro ""Números de serie en garantía"".';
				|tr = '""Stok kayıt detayları olarak seri numaraları kullan"" seçeneği etkinleştirilemiyor.
				|""Garantide seri numaraları"" kaydında girişler var.';
				|it = 'Impossibile attivare ""Controllo scorte secondo numero di serie"".
				|Ci sono inserimenti nel registro ""Numeri di serie nella garanzia"".';
				|de = 'Sie können ""Seriennummern als Bestandsdetails verwenden"" nicht aktivieren.
				|Es gibt Einträge im Register ""Seriennummern im Garantieschein"".'");
		EndIf;
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseStorageBins option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingByCells()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionAccountingByCells();
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseCharachteristics option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseCharacteristics()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionUseCharacteristics();
	
	// begin Drive.FullVersion
	// end Drive.FullVersion
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseBatches option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseBatches()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionUseBatches();
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseDiscountsInPurchases option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscounts()
	
	ErrorText = "";
	
	ArrayOfDocuments = New Array;

	ArrayOfDocuments.Add("Document.SupplierQuote.Inventory");
	ArrayOfDocuments.Add("Document.PurchaseOrder.Inventory");
	ArrayOfDocuments.Add("Document.GoodsReceipt.Products");
	ArrayOfDocuments.Add("Document.SupplierInvoice.Inventory");
	
	QueryPattern = 
	"SELECT TOP 1
	|	CWT_Of_Document.Ref AS Ref
	|FROM
	|	&DocumentTabularSection AS CWT_Of_Document
	|WHERE
	|	CWT_Of_Document.DiscountPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement In ArrayOfDocuments Do
		If Not IsBlankString(Query.Text) Then
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
		EndIf;
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF)
			+ NStr("en = 'Discounts are already used in the database. You can''t unmark the checkbox.'; ru = 'В базе уже используются скидки. Отключить флажок нельзя.';pl = 'Rabaty są już użyte w bazie danych. Nie można odznaczyć pola wyboru.';es_ES = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';es_CO = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';tr = 'Veritabanında indirimler kullanımda. Bu onay kutusu temizlenemez.';it = 'Gli sconti sono già utilizzati nel database. Non potete deselezionare la casella di controllo.';de = 'Rabatte werden bereits in der Datenbank verwendet. Sie können das Kontrollkästchen nicht deaktivieren.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckUseSubcontractorOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SubcontractorOrderIssued.Ref AS Ref,
	|	SubcontractorOrderIssued.OrderState.OrderStatus AS OrderStatus
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|		INNER JOIN Catalog.SubcontractorOrderIssuedStatuses AS SubcontractorOrderIssuedStatuses
	|		ON SubcontractorOrderIssued.OrderState = SubcontractorOrderIssuedStatuses.Ref
	|WHERE
	|	(SubcontractorOrderIssuedStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR SubcontractorOrderIssuedStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT SubcontractorOrderIssued.Closed)";
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Subcontractor orders issued. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Opened"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для выданных заказов на переработку. Чтобы снять этот флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт"",
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт), измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można odznaczyć tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla wydanych zamówień wykonawcy. Aby odznaczyć pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończone"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes emitidas del subcontratista. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes emitidas del subcontratista. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Düzenlenen alt yüklenici siparişleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu siparişlerin durumlarını değiştirin.
			|""Açık"" durumundaki siparişlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki siparişlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için siparişleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono già impostati per gli Ordini di subfornitura emessi. Per poter deselezionare questa casella di controllo, 
			|modificare gli stati di questi ordini. Per ordini con stato ""Aperto"", 
			|modificare lo stato in ""In lavorazione"" o ""Completato"" (chiuso).
			|Per ordini con stato ""Completato"" (non chiuso), modificare lo stato in ""Completato"" (chiuso).
			|Per fare questo, chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für erteilte Subunternehmeraufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckUseAccountPayableAdjustments()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DebitNote.Ref AS Ref
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	NOT DebitNote.DeletionMark
	|	AND DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)";
	
	If Not Query.Execute().IsEmpty() Then
		ErrorText = NStr("en = 'You cannot disable Adjust accounts payable option because
			|there are Debit notes with the Accounts payable adjustments operation.'; 
			|ru = 'Нельзя отключить опцию ""Корректировать кредиторскую задолженность"", так как
			|имеются дебетовые авизо с операцией корректировки кредиторской задолженности.';
			|pl = 'Nie możesz wyłączyć opcji Dostosuj zobowiązania ponieważ
			|istnieją Noty debetowe z operacją korekty zobowiązań.';
			|es_ES = 'No puede desactivar la variante Ajustar cuentas por pagar porque
			|hay notas de débito con la operación de ajustes de cuentas por pagar.';
			|es_CO = 'No puede desactivar la opción Ajustar cuentas por pagar porque
			|hay notas de débito con la operación de ajustes de cuentas por pagar.';
			|tr = '''Borç hesaplarını düzelt'' seçeneği devre dışı bırakılamıyor çünkü
			|Borç hesaplarını düzeltme işlemi olan Borç dekontları var.';
			|it = 'Impossibile disabilitare l''opzione Regolare debiti contabili, poiché 
			|vi sono note di addebito con l''opzione Regolamenti debiti contabili.';
			|de = 'Sie können die Option „Offene Posten Kreditoren korrigieren“ nicht deaktivieren, 
			|da Belastungen mit der Operation „Korrekturen von Offenen Posten Kreditoren“ vorhanden sind.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check for the option to uncheck UsePurchaseOrderApproval.
//
Function CancelRemoveFunctionalOptionUsePurchaseOrderApproval() Export
	
	ErrorText = "";
	AreRecords = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	PurchaseOrder.Ref AS Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.ApprovalStatus <> VALUE(Enum.ApprovalStatuses.EmptyRef)
	|	AND NOT PurchaseOrder.DeletionMark";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'You cannot disable ""Purchase order approval"" once used.'; ru = 'Отключение ""Утверждения заказа поставщику"" после использования невозможно.';pl = 'Nie można wyłączyć opcji „Zatwierdzenie zamówienia zakupu”.';es_ES = 'No se puede desactivar ""Aprobar la orden de compra"" una vez utilizado.';es_CO = 'No se puede desactivar ""Aprobar la orden de compra"" una vez utilizado.';tr = '""Satın alma siparişi onayı"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Impossibile disabilitare ""Approvazione ordine di acquisto"" una volta utilizzato.';de = 'Sie können die bereits verwendete ""Genehmigung der Bestellung an Lieferanten"" nicht deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckChangingWeightUOM()
	
	ErrorText = "";
	
	Query = New Query(
	"SELECT TOP 1
	|	PackingSlip.Ref AS Ref
	|FROM
	|	Document.PackingSlip AS PackingSlip
	|WHERE
	|	PackingSlip.Posted");
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'You cannot change the weight unit because ""Packing slips"" are already registered.'; ru = 'Изменение единицы массы невозможно, поскольку упаковочные листы уже зарегистрированы.';pl = 'Nie możesz zmienić jednostkę wagi ponieważ ""Listy przewozowe"" są już zarejestrowane.';es_ES = 'Usted no puede cambiar la unidad de peso porque los ""Albaranes de entrega"" ya están registrados.';es_CO = 'Usted no puede cambiar la unidad de peso porque los ""Albaranes de entrega"" ya están registrados.';tr = '""Sevk irsaliyeleri"" zaten kayıtlı olduğu için ağırlık birimi değiştirilemez.';it = 'Impossibile modificare l''unità di peso poiché le ""Packing list"" sono già state registrate.';de = 'Sie können die Gewichtseinheiten nicht ändern, denn die ""Packzettel"" sind bereits registriert.'");
		
	EndIf;
	
	Return ErrorText;

	
EndFunction

// Check for the option to uncheck UseZeroInvoicePurchases.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseZeroInvoicePurchases()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SupplierInvoice.Ref AS Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.ZeroInvoice)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. 
			|Supplier invoices with a zero invoice type are already registered.'; 
			|ru = 'Не удается снять флажок.
			|Нулевые инвойсы на оплату уже зарегистрированы.';
			|pl = 'Nie można wyczyścić pola wyboru. 
			|Faktury zakupu z zerowym typem faktury są już zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificación. 
			|Las facturas del proveedor con un tipo de factura con importe cero ya están registradas.';
			|es_CO = 'No se puede desmarcar la casilla de verificación. 
			|Las facturas de compra con un tipo de factura con importe cero ya están registradas.';
			|tr = 'Onay kutusu temizlenemedi. 
			|Sıfır bedelli fatura türü satın alma faturaları zaten kaydedildi.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|Le fatture di acquisto con tipo Fattura a zero sono già state registrate.';
			|de = 'Das Kontrollkästchen kann nicht deaktiviert werden. 
			|Lieferantenrechnungen mit dem Rechnungstyp Null sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckUseProductCrossReferences()
	
	Result = False;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SuppliersProducts.Ref AS Ref
	|FROM
	|	Catalog.SuppliersProducts AS SuppliersProducts";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Result = True;
	EndIf;
	
	Return Result;
	
EndFunction

// KitProcessing

&AtServer
Function CancellationUncheckFunctionalOptionUseOldProduction()
	
	ErrorText = "";
	
	If ThereAreKitProcessedDocsInBase() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. 
			|Kit processed documents are already registered.'; 
			|ru = 'Не удается снять флажок.
			|Документы результата комплектации уже зарегистрированы.';
			|pl = 'Nie można wyczyścić tego pola wyboru. 
			|Dokumenty przetwarzanego zestawu są już zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificación. 
			|Los documentos del kit procesado ya están registrados.';
			|es_CO = 'No se puede desmarcar la casilla de verificación. 
			|Los documentos del kit procesado ya están registrados.';
			|tr = 'Onay kutusu temizlenemiyor. 
			|Kayıtlı İşlenen set belgeleri var.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|I documenti del kit elaborato sono già registrati.';
			|de = 'Kann das Kontrollkästchen nicht deaktivieren.
			|Bearbeitete Dokumente für Kit sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckUseKitOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	KitOrder.Ref AS Ref,
	|	KitOrderStatuses.OrderStatus AS OrderStatus
	|FROM
	|	Document.KitOrder AS KitOrder
	|		INNER JOIN Catalog.KitOrderStatuses AS KitOrderStatuses
	|		ON KitOrder.OrderState = KitOrderStatuses.Ref
	|WHERE
	|	(KitOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR KitOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT KitOrder.Closed)";
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Kit orders. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Opened"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для заказов на комплектацию. Чтобы снять флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт""
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт) измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można wyczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla Zamówień zestawów. Aby móc wyczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para los pedidos del kit. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para los pedidos del kit. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Set siparişleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu siparişlerin durumlarını değiştirin.
			|""Açık"" durumundaki siparişlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki siparişlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için siparişleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono già impostati per gli Ordini kit. Per poter deselezionare la casella di controllo,
			|modificare lo stato di tali ordini. Per gli ordini con stato ""Aperto"", 
			|modificare lo stato a ""In corso"" o ""Completato"" (chiuso).
			| per gli ordini con stato ""Completato"" (non chiuso), modificare lo stato a ""Completato"" (chiuso).
			| Per fare ciò, è necessario chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Kit-Aufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckFunctionalOptionUseByProductsInKitProcessing()
	
	ErrorText = "";
	
	If ThereAreKitProcessedWithByProductsDocsInBase() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. Kit processed documents are already registered. They include by-products.'; ru = 'Не удается снять флажок. Документы результата комплектации уже зарегистрированы. Они содержат побочную продукцию.';pl = 'Nie można wyczyścić tego pola wyboru. Dokumenty przetwarzanego zestawu są już zarejestrowane. Zawierają one produkty uboczne.';es_ES = 'No se puede desmarcar la casilla de verificación. Los documentos del kit procesado ya están registrados. Incluyen los trozos y deterioros.';es_CO = 'No se puede desmarcar la casilla de verificación. Los documentos del kit procesado ya están registrados. Incluyen los trozos y deterioros.';tr = 'Onay kutusu temizlenemiyor. Kayıtlı İşlenen set belgeleri mevcut. Bu belgeler yan ürünler içeriyor.';it = 'Impossibile deselezionare la casella di controllo. I documenti del kit elaborato sono già registrati. Includono sottoprodotti.';de = 'Kann das Kontrollkästchen nicht deaktivieren. Bearbeitete Dokumente für Kit sind bereits registriert. Sie enthalten Nebenprodukte.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

// End KitProcessing

// The removal control procedure of the Subcontracting option.
//
&AtServer
Function CancellationUncheckFunctionalOptionCanReceiveSubcontractingServices()
	
	ErrorText = "";
	
	CanReceiveSubcontractingServices = ConstantsSet.CanReceiveSubcontractingServices;
	
	If Not CanReceiveSubcontractingServices Then
	
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	SubcontractorOrderIssued.Ref AS Ref
		|FROM
		|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	SubcontractorInvoiceReceived.Ref AS Ref
		|FROM
		|	Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	GoodsIssue.Ref AS Ref
		|FROM
		|	Document.GoodsIssue AS GoodsIssue
		|WHERE
		|	GoodsIssue.OperationType = VALUE(ENUM.OperationTypesGoodsIssue.TransferToSubcontractor)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	GoodsReceipt.Ref AS Ref
		|FROM
		|	Document.GoodsReceipt AS GoodsReceipt
		|WHERE
		|	GoodsReceipt.OperationType = VALUE(ENUM.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	GoodsReceipt.Ref AS Ref
		|FROM
		|	Document.GoodsReceipt AS GoodsReceipt
		|WHERE
		|	GoodsReceipt.OperationType = VALUE(ENUM.OperationTypesGoodsReceipt.ReturnFromSubcontractor)";
		// begin Drive.FullVersion
		Query.Text = Query.Text + ";
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	ManufacturingOperation.Ref AS Ref
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.ProductionMethod = VALUE(ENUM.ProductionMethods.Subcontracting)";
		// end Drive.FullVersion
		
		ResultsArray = Query.ExecuteBatch();
		
		// 1. Subcontractor order issued Document.
		If Not ResultsArray[0].IsEmpty() Then
			
			ErrorText = NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Subcontractor order issued"" documents are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Выданный заказ на переработку"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Wydane zamówienie wykonawcy"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Orden emitida del subcontratista"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Orden emitida del subcontratista"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Düzenlenen alt yüklenici siparişi"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Ordine subfornitura emesso"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Subunternehmerauftrag ausgestellt"" sind bereits eingetragen.'");
			
		EndIf;
		
		// 2. Subcontractor invoice received Document.
		If Not ResultsArray[1].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Subcontractor invoice received"" documents are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Полученный инвойс переработчика"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Otrzymana faktura podwykonawcy"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Factura del subcontratista recibida"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Factura del subcontratista recibida"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Alınan alt yüklenici faturası"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Fattura di subappalto ricevuta"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Subunternehmerrechnung erhalten"" sind bereits eingetragen.'");
			
		EndIf;
		
		// 3. Goods issue Document.
		If Not ResultsArray[2].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Goods issue"" documents with the ""Transfer to a subcontractor"" operation are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Отпуск товаров"" с операцией ""Передача переработчику"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Wydanie zewnętrzne"" z operacją ""Przeniesienie do podwykonawcy"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Salida de mercancías"" con la operación ""Transferir a un subcontratista"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Salida de mercancías"" con la operación ""Transferir a un subcontratista"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Alt yükleniciye transfer"" işlemli ""Ambar çıkışı"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Spedizione merce/DDT"" con operazione ""Trasferito a un subfornitore"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Warenausgang"" mit der Operation ""Auf Subunternehmer übertragen"" sind bereits eingetragen.'");
			
		EndIf;
		
		// 4. Goods receipt Document with "Receipt from a subcontractor".
		If Not ResultsArray[3].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Goods receipt"" documents with the ""Receipt from a subcontractor"" operation are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Поступление товаров"" с операцией ""Поступление от переработчика"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Przyjęcie zewnętrzne"" z operacją ""Przyjęcie od podwykonawcy"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Recibo de mercancías"" con la operación ""Recepción del subcontratista"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Recibo de mercancías"" con la operación ""Recepción del subcontratista"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Alt yüklenici fişi"" işlemli ""Ambar girişi"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Ricezione merce"" con operazione ""Ricevuto da un subfornitore"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Wareneingang"" mit der Operation ""Eingang von einem Subunternehmer"" sind bereits eingetragen.'");
			
		EndIf;
		
		// 5. Goods receipt Document with "Return from a subcontractor".
		If Not ResultsArray[4].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Goods receipt"" documents with the ""Return from a subcontractor"" operation are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Поступление товаров"" с операцией ""Возврат от переработчика"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Przyjęcie zewnętrzne"" z operacją ""Zwrot od podwykonawcy"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Recibo de mercancías"" con la operación ""Devolución del subcontratista"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos de ""Recibo de mercancías"" con la operación ""Devolución del subcontratista"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Alt yüklenici iadesi"" işlemli ""Ambar girişi"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Ricezione merce"" con operazione ""Restituito da un subfornitore"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Wareneingang"" mit der Operation ""Rückgabe von einem Subunternehmer"" sind bereits eingetragen.'");
			
		EndIf;
		
		// begin Drive.FullVersion
		
		// 6. WIP Document with ProductionMethod "Subcontracting".
		If Not ResultsArray[5].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Cannot clear the ""Receive subcontracting services"" checkbox. The ""Work-in-progress"" documents with the ""Subcontracting"" production method are already registered.'; ru = 'Не удалось снять флажок ""Получать услуги переработки"". Документы ""Незавершенное производство"" со способом производства ""Переработка"" уже зарегистрированы.';pl = 'Nie można odznaczyć pola wyboru ""Otrzymuj usługi podwykonawstwa"". Dokumenty ""Praca w toku"" z operacją ""Podwykonawstwo"" są już zarejestrowane.';es_ES = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Trabajo en progreso"" con el método de producción ""Subcontratación"" ya están registrados.';es_CO = 'No se puede desactivar la casilla ""Recibir servicios de subcontratación"". Los documentos ""Trabajo en progreso"" con el método de producción ""Subcontratación"" ya están registrados.';tr = '""Alt yüklenici hizmetleri al"" onay kutusu temizlenemiyor. ""Taşeronluk"" üretim yöntemli ""İşlem bitişi"" belgelerinin kayıtları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Ricevere servizi di subappalto"". I documenti ""Lavoro in corso"" con metodo di produzione ""Subappalto"" sono già registrati.';de = 'Das Kontrollkästchen ""Dienstleistungen von Subunternehmerbestellung erhalten"" kann nicht deaktiviert werden. Die Dokumente ""Arbeit in Bearbeitung"" mit der Produktionsmethode ""Subunternehmerbestellung"" sind bereits eingetragen.'");
			
		EndIf;
		
		// end Drive.FullVersion
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are the Purchase order documents with the status other than Executed,then it is not allowed to remove the flag.
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" Then
		
		If Constants.UsePurchaseOrderStatuses.Get() <> ConstantsSet.UsePurchaseOrderStatuses
			And (Not ConstantsSet.UsePurchaseOrderStatuses) Then
			
			ErrorText = CancellationUncheckUsePurchaseOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStatuses
			And Not ValueIsFilled(ConstantsSet.PurchaseOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'Specify the ""In progress"" status.'; ru = 'Укажите статус ""В работе""';pl = 'Określ status ""W toku"".';es_ES = 'Especifique el estado ""En curso"".';es_CO = 'Especifique el estado ""En curso"".';tr = '""İşlemde"" durumunu belirtin.';it = 'Specificare lo stato ""In lavorazione"".';de = 'Geben Sie den Status ""In Bearbeitung"" an.'");
			
			Result.Insert("Field", 			AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersCompletionStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersCompletionStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStatuses
			And Not ValueIsFilled(ConstantsSet.PurchaseOrdersCompletionStatus) Then
			
			ErrorText = NStr("en = 'Specify the ""Completed"" status.'; ru = 'Укажите статус ""Завершено""';pl = 'Określ status ""Zakończono"".';es_ES = 'Especifique el estado ""Completado"".';es_CO = 'Especifique el estado ""Completado"".';tr = '""Tamamlandı"" durumunu belirtin.';it = 'Specificare lo stato ""Completato"".';de = 'Geben Sie den Status ""Abgeschlossen"" an.'");
			
			Result.Insert("Field", 			AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersCompletionStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are documents Transfer order with the status which differs from Executed, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseTransferOrderStatuses" Then
		
		If Constants.UseTransferOrderStatuses.Get() <> ConstantsSet.UseTransferOrderStatuses
			And (Not ConstantsSet.UseTransferOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseTransferOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the TransferOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.TransferOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseTransferOrderStatuses
			And Not ValueIsFilled(ConstantsSet.TransferOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several transfer order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько статусов заказов на перемещение"", но не заполнен параметр состояния ""В работе"".';pl = 'Pole wyboru ""Użyj kilku statusów zamówienia przeniesienia"" jest odznaczone, ale parametr ""W toku"" nie jest wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes de transferencia"" está vaciada pero el parámetro del estado ""En progreso"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes de transferencia"" está vaciada pero el parámetro del estado ""En progreso"" no está rellenado.';tr = '""Birkaç transfer emri durumu kullan"" onay kutusu temizlendi, ancak ""Devam ediyor"" durum parametresi doldurulmadı.';it = 'La casella di controllo ""Utilizza più stati dell''ordine di trasferimento"" non è selezionata, ma il parametro di stato ""In lavorazione"" non è compilato.';de = 'Das Kontrollkästchen ""Mehrere Status von Transportauftrag verwenden"" ist deaktiviert, aber der Statusparameter ""In Bearbeitung"" ist nicht ausgefüllt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.TransferOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedTransferOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedTransferOrders" Then
		
		If Not ConstantsSet.UseTransferOrderStatuses
			And Not ValueIsFilled(ConstantsSet.StateCompletedTransferOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several transfer order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько статусов заказов на перемещение"", но не заполнен параметр состояния ""Завершен.';pl = 'Pole wyboru ""Użyj kilku statusów zamówienia przeniesienia"" jest odznaczone, ale parametr ""Zakończono"" nie został wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes de transferencia"" está vaciada pero el parámetro del estado ""Finalizado"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes de transferencia"" está vaciada pero el parámetro del estado ""Finalizado"" no está rellenado.';tr = '""Birkaç transfer emri durumu kullan"" onay kutusu temizlendi, ancak ""Tamamlandı"" durum parametresi doldurulmadı.';it = 'La casella di controllo ""Utilizza più stati dell''ordine di trasferimento"" non è selezionata, ma il parametro di stato ""Completato"" non è compilato.';de = 'Das Kontrollkästchen ""Mehrere Status von Transportauftrag verwenden"" ist deaktiviert, aber der Statusparameter ""Abgeschlossen"" ist nicht ausgefüllt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedTransferOrders.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are references to the warehouses not equal to the main warehouse, the removal of the UseSeveralWarehouses
	// flag is prohibited
	If AttributePathToData = "ConstantsSet.UseSeveralWarehouses" Then
		
		If Constants.UseSeveralWarehouses.Get() <> ConstantsSet.UseSeveralWarehouses
			And (Not ConstantsSet.UseSeveralWarehouses) Then
			
			ErrorText = CancellationUncheckAccountingBySeveralWarehouses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the documents contain any references to UOM, it is not allowed to remove the UseSeveralUnitsForProduct flag	
	If AttributePathToData = "ConstantsSet.UseSeveralUnitsForProduct" Then
			
		If Constants.UseSeveralUnitsForProduct.Get() <> ConstantsSet.UseSeveralUnitsForProduct 
			And (Not ConstantsSet.UseSeveralUnitsForProduct) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingInVariousUOM();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Warehouse inventory" for a non-empty cell, the clearing of the
	// UseStorageBins check box is prohibited
	If AttributePathToData = "ConstantsSet.UseStorageBins" Then
		
		If Constants.UseStorageBins.Get() <> ConstantsSet.UseStorageBins 
			And (Not ConstantsSet.UseStorageBins) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingByCells();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in the variant registers, the clearing of the UseVariants check box is prohibited
	If AttributePathToData = "ConstantsSet.UseCharacteristics" Then
		
		If Constants.UseCharacteristics.Get() <> ConstantsSet.UseCharacteristics
			And (Not ConstantsSet.UseCharacteristics) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseCharacteristics();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in registers containing batches, it is not allowed to clear the UseBatches check box
	If AttributePathToData = "ConstantsSet.UseBatches" Then
		
		If Constants.UseBatches.Get() <> ConstantsSet.UseBatches
			And (Not ConstantsSet.UseBatches) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseBatches();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck UseSerialNumbers.
	If AttributePathToData = "ConstantsSet.UseSerialNumbers" Then
		
		If Constants.UseSerialNumbers.Get() <> ConstantsSet.UseSerialNumbers 
			And (Not ConstantsSet.UseSerialNumbers) Then
			
			ErrorText = CancelRemoveFunctionalOptionUseSerialNumbers();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;

	// Check for the option to uncheck UseSerialNumbersAsInventoryRecordDetails.
	If AttributePathToData = "ConstantsSet.UseSerialNumbersAsInventoryRecordDetails" Then
		
		If Constants.UseSerialNumbersAsInventoryRecordDetails.Get() <> ConstantsSet.UseSerialNumbersAsInventoryRecordDetails Then
			
			If ConstantsSet.UseSerialNumbersAsInventoryRecordDetails Then
				
				ErrorText = CancelChangeUseSerialNumbersAsInventoryRecordDetails(False);
				If Not IsBlankString(ErrorText) Then
					Result.Insert("Field",			AttributePathToData);
					Result.Insert("ErrorText",		ErrorText);
					Result.Insert("CurrentValue",	False);
				EndIf;
				
			Else
				
				ErrorText = CancelChangeUseSerialNumbersAsInventoryRecordDetails();
				If Not IsBlankString(ErrorText) Then
					Result.Insert("Field",			AttributePathToData);
					Result.Insert("ErrorText",		ErrorText);
					Result.Insert("CurrentValue",	True);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Warehouse inventory" for a non-empty cell, the clearing of the
	// UseStorageBins check box is prohibited
	If AttributePathToData = "ConstantsSet.UseDiscountsInPurchases" Then
		
		If Constants.UseDiscountsInPurchases.Get() <> ConstantsSet.UseDiscountsInPurchases
			And (Not ConstantsSet.UseDiscountsInPurchases) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscounts();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderApproval" Then
		
		If Constants.UsePurchaseOrderApproval.Get() <> ConstantsSet.UsePurchaseOrderApproval Then
			
			If Constants.UseBusinessProcessesAndTasks.Get() <> ConstantsSet.UsePurchaseOrderApproval
				And ConstantsSet.UsePurchaseOrderApproval Then
				
				Constants.UseBusinessProcessesAndTasks.Set(True);
				
			ElsIf (Not ConstantsSet.UsePurchaseOrderApproval) Then
				
				ErrorText = CancelRemoveFunctionalOptionUsePurchaseOrderApproval();
				If Not IsBlankString(ErrorText) Then
					
					Result.Insert("Field", 			AttributePathToData);
					Result.Insert("ErrorText", 		ErrorText);
					Result.Insert("CurrentValue",	True);
					
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck WeightUOM.
	If AttributePathToData = "ConstantsSet.WeightUOM" Then
		
		If Constants.WeightUOM.Get() <> ConstantsSet.WeightUOM Then
			
			ErrorText = CancellationUncheckChangingWeightUOM();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck UseZeroInvoicePurchases.
	If AttributePathToData = "ConstantsSet.UseZeroInvoicePurchases" Then
		
		If Constants.UseZeroInvoicePurchases.Get() <> ConstantsSet.UseZeroInvoicePurchases
			And (Not ConstantsSet.UseZeroInvoicePurchases) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseZeroInvoicePurchases();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseSubcontractorOrderIssuedStatuses" Then
		
		If Constants.UseSubcontractorOrderIssuedStatuses.Get() <> ConstantsSet.UseSubcontractorOrderIssuedStatuses
			And Not ConstantsSet.UseSubcontractorOrderIssuedStatuses Then
			
			ErrorText = CancellationUncheckUseSubcontractorOrderStates();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;

	If AttributePathToData = "ConstantsSet.SubcontractorOrderIssuedInProgressStatus" Then
		
		If Not ConstantsSet.UseSubcontractorOrderIssuedStatuses
			And Not ValueIsFilled(ConstantsSet.SubcontractorOrderIssuedInProgressStatus) Then
			
			ErrorText = NStr("en = 'When the ""Several subcontractor order statuses"" check box is cleared,
				| the ""In progress"" status field is required.'; 
				|ru = 'При снятии флажка ""Несколько статусов заказов на переработку""
				|поле статуса ""В работе"" является обязательным.';
				|pl = 'Gdy pole ""Kilka statusów zamówienia podwykonawcy"" jest wyczyszczone,
				| wymagany jest status pola ""W toku"".';
				|es_ES = 'Si la casilla de verificación ""Varios estados de la orden del subcontratista"" está desmarcada,
				| el campo de estado ""En progreso"" es obligatorio.';
				|es_CO = 'Si la casilla de verificación ""Varios estados de la orden del subcontratista"" está desmarcada,
				| el campo de estado ""En progreso"" es obligatorio.';
				|tr = '""Birden fazla alt yüklenici siparişi durumu"" onay kutusu temizlendiğinde
				| ""İşlemde"" durum alanı gereklidir.';
				|it = 'Quando la casella di controllo ""Diversi stati ordine subfornitura ricevuti"" è deselezionata,
				| è richiesto il campo di stato ""In lavorazione"".';
				|de = 'Wenn das Kontrollkästchen ""Mehrere Status von Subunternehmerauftrag"" gelöscht ist, wird
				| das Statusfeld ""In Bearbeitung"" benötigt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.SubcontractorOrderIssuedInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.SubcontractorOrderIssuedCompletionStatus" Then
		
		If Not ConstantsSet.UseSubcontractorOrderIssuedStatuses
			And Not ValueIsFilled(ConstantsSet.SubcontractorOrderIssuedCompletionStatus) Then
			
			ErrorText = NStr("en = 'When the ""Several subcontractor order statuses"" check box is cleared,
				| the ""Completed"" status field is required.'; 
				|ru = 'При снятии флажка ""Несколько статусов заказов на переработку""
				|поле статуса ""Завершен"" является обязательным.';
				|pl = 'Gdy pole ""Kilka statusów zamówienia podwykonawcy"" jest wyczyszczone,
				| wymagany jest status pola ""Zakończono"".';
				|es_ES = 'Si la casilla de verificación ""Varios estados de la orden del subcontratista"" está desmarcada,
				| el campo de estado ""Completado"" es obligatorio.';
				|es_CO = 'Si la casilla de verificación ""Varios estados de la orden del subcontratista"" está desmarcada,
				| el campo de estado ""Completado"" es obligatorio.';
				|tr = '""Birden fazla alt yüklenici siparişi durumu"" onay kutusu temizlendiğinde
				| ""Tamamlandı"" durum alanı gereklidir.';
				|it = 'Quando la casella di controllo ""Diversi stati ordine di subfornitura ricevuto"" è deselezionata, 
				|è richiesto il campo dello stato ""Completato"".';
				|de = 'Wenn das Kontrollkästchen ""Mehrere Status von Subunternehmerauftrag"" gelöscht ist, wird
				| das Statusfeld ""Abgeschlossen"" benötigt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.SubcontractorOrderIssuedCompletionStatus.Get());
			
		EndIf; 
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseAccountPayableAdjustments" Then
		
		If Not ConstantsSet.UseAccountPayableAdjustments
			And Constants.UseAccountPayableAdjustments.Get() <> ConstantsSet.UseAccountPayableAdjustments Then
			
			ErrorText = CancellationUncheckUseAccountPayableAdjustments();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// KitProcessing
	
	If AttributePathToData = "ConstantsSet.UseKitProcessing" Then
		
		If Constants.UseKitProcessing.Get() <> ConstantsSet.UseKitProcessing
			And (Not ConstantsSet.UseKitProcessing) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseOldProduction();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Constants.UseKitProcessing.Get());
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseKitOrderStatuses" Then
		
		If Constants.UseKitOrderStatuses.Get() <> ConstantsSet.UseKitOrderStatuses
			And Not ConstantsSet.UseKitOrderStatuses Then
			
			ErrorText = CancellationUncheckUseKitOrderStatuses();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	Constants.UseKitOrderStatuses.Get());
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseByProductsInKitProcessing" Then
		
		If Constants.UseByProductsInKitProcessing.Get() <> ConstantsSet.UseByProductsInKitProcessing
			And Not ConstantsSet.UseByProductsInKitProcessing Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseByProductsInKitProcessing();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	Constants.UseByProductsInKitProcessing.Get());
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.KitOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseKitOrderStatuses
			And Not ValueIsFilled(ConstantsSet.KitOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'When the ""Several kit order statuses"" check box is cleared,
				| the ""In progress"" status field is required.'; 
				|ru = 'При снятии флажка ""Несколько статусов заказов на комплектацию""
				|поле статуса ""В работе"" является обязательным.';
				|pl = 'Gdy pole ""Kilka statusów zamówienia zestawu"" jest wyczyszczone,
				| wymagany jest status pola ""W toku"".';
				|es_ES = 'Si la casilla de verificación ""Varios estados del pedido del kit"" está desmarcada,
				| el campo de estado ""En progreso"" es obligatorio.';
				|es_CO = 'Si la casilla de verificación ""Varios estados del pedido del kit"" está desmarcada,
				| el campo de estado ""En progreso"" es obligatorio.';
				|tr = '""Birden fazla set siparişi durumu"" onay kutusu temizlendiğinde
				| ""İşlemde"" durum alanı gereklidir.';
				|it = 'Quando la casella di controllo ""Diversi stati ordine kit"" è deselezionata, 
				|è richiesto il campo dello stato ""In corso"".';
				|de = 'Wenn das Kontrollkästchen ""Mehrere Status von Kit-Auftrag"" gelöscht ist, 
				| wird das Statusfeld ""In Bearbeitung"" benötigt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.KitOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.KitOrdersCompletionStatus" Then
		
		If Not ConstantsSet.UseKitOrderStatuses
			And Not ValueIsFilled(ConstantsSet.KitOrdersCompletionStatus) Then
			
			ErrorText = NStr("en = 'When the ""Several kit order statuses"" check box is cleared,
				| the ""Completed"" status field is required.'; 
				|ru = 'При снятии флажка ""Несколько статусов заказов на комплектацию""
				|поле статуса ""Завершен"" является обязательным.';
				|pl = 'Gdy pole ""Kilka statusów zamówienia zestawu"" jest wyczyszczone,
				| wymagany jest status pola ""Zakończono"".';
				|es_ES = 'Si la casilla de verificación ""Varios estados del pedido del kit"" está desmarcada,
				| el campo de estado ""Finalizado"" es obligatorio.';
				|es_CO = 'Si la casilla de verificación ""Varios estados del pedido del kit"" está desmarcada,
				| el campo de estado ""Finalizado"" es obligatorio.';
				|tr = '""Birden fazla set siparişi durumu"" onay kutusu temizlendiğinde
				| ""Tamamlandı"" durum alanı gereklidir.';
				|it = 'Quando la casella di controllo ""Diversi stati ordine kit"" è deselezionata, 
				|è richiesto il campo dello stato ""Completato"".';
				|de = 'Wenn das Kontrollkästchen ""Mehrere Status von Kit-Auftrag"" gelöscht ist, 
				| wird das Statusfeld ""Abgeschlossen"" benötigt.'");
			
			Result.Insert("Field",			AttributePathToData);
			Result.Insert("ErrorText",		ErrorText);
			Result.Insert("CurrentValue",	Constants.KitOrdersCompletionStatus.Get());
			
		EndIf; 
		
	EndIf;
	
	// End KitProcessing
	
	If AttributePathToData = "ConstantsSet.CanReceiveSubcontractingServices" Then
		
		If Constants.CanReceiveSubcontractingServices.Get() <> ConstantsSet.CanReceiveSubcontractingServices
			And Not ConstantsSet.CanReceiveSubcontractingServices Then
		
			ErrorText = CancellationUncheckFunctionalOptionCanReceiveSubcontractingServices();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Not ConstantsSet.CanReceiveSubcontractingServices);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

// Procedure updates the parameters of the transfer order status.
//
&AtServerNoContext
Procedure UpdateTransferOrderStatesOnChange()
	
	InProcessStatus = Constants.TransferOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedTransferOrders.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	TransferOrderStatuses.Ref AS State
		|FROM
		|	Catalog.TransferOrderStatuses AS TransferOrderStatuses
		|WHERE
		|	TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.TransferOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	TransferOrderStatuses.Ref AS State
		|FROM
		|	Catalog.TransferOrderStatuses AS TransferOrderStatuses
		|WHERE
		|	TransferOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.StateCompletedTransferOrders.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeEmployeeApprovingPurchases()
	
	EmployeeApprovingPurchases = Catalogs.PerformerRoles.EmployeeApprovingPurchases.GetObject();
	EmployeeApprovingPurchases.UsedWithoutAddressingObjects	= Not ConstantsSet.UseSeparateApproversForCompanies;
	EmployeeApprovingPurchases.UsedByAddressingObjects = ConstantsSet.UseSeparateApproversForCompanies;
	EmployeeApprovingPurchases.MainAddressingObjectTypes = ChartsOfCharacteristicTypes.TaskAddressingObjects.Company;
	EmployeeApprovingPurchases.Write();
	
EndProcedure

&AtClient
Procedure StartApprovalSettingsInCatalogsChange()
	
	Text = NStr("en = 'Do you want to apply the settings for existing catalogs?'; ru = 'Применить настройки к существующим справочникам?';pl = 'Czy chcesz zastosować ustawienia do istniejących katalogów?';es_ES = '¿Quiere aplicar las configuraciones de los catálogos existentes?';es_CO = '¿Quiere aplicar las configuraciones de los catálogos existentes?';tr = 'Mevcut kataloglar için ayarları uygulamak istiyor musunuz?';it = 'Applicare le impostazioni per i cataloghi esistenti?';de = 'Möchten Sie die Einstellungen für den vorhandenen Katalog anwenden?'");
	Notification = New NotifyDescription("StartApprovalSettingsInCatalogsChangeEnd", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure StartApprovalSettingsInCatalogsChangeEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		BackgroundJob = StartApprovalSettingsInCatalogsChangeInBackgroundJob();
		
		WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		WaitSettings.OutputIdleWindow = False;
		
		Handler = New NotifyDescription("AfterChangeApprovalSettingsInCatalogs", ThisObject);
		TimeConsumingOperationsClient.WaitForCompletion(BackgroundJob, Handler, WaitSettings);
		
	EndIf;
	
EndProcedure

&AtServer
Function StartApprovalSettingsInCatalogsChangeInBackgroundJob()
	
	ProcedureParameters = New Structure("ApprovePurchaseOrders, LimitWithoutApproval",
		ConstantsSet.LimitWithoutPurchaseOrderApproval > 0,
		ConstantsSet.LimitWithoutPurchaseOrderApproval);
		
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Change apporval settings in catalogs'; ru = 'Изменить настройки утверждения в справочниках';pl = 'Zmień ustawienia zatwierdzania w katalogach';es_ES = 'Cambiar las configuraciones de aprobación en los catálogos';es_CO = 'Cambiar las configuraciones de aprobación en los catálogos';tr = 'Kataloglarda onay ayarlarını değiştir';it = 'Modificare le impostazioni di approvazione nei cataloghi';de = 'Genehmigungseinstellungen in Katalogen ändern'");
	ExecutionParameters.WaitForCompletion = 0;
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"BusinessProcesses.PurchaseApproval.ChangeApprovalSettingsInCatalogs",
		ProcedureParameters,
		ExecutionParameters);
	
EndFunction

&AtClient
Procedure AfterChangeApprovalSettingsInCatalogs(BackgroundJob, AdditionalParameters) Export

	If BackgroundJob <> Undefined
		And BackgroundJob.Status = "Completed" Then
		
		ShowUserNotification(NStr("en = 'Approval settings are changed.'; ru = 'Настройки утверждения изменены.';pl = 'Zatwierdzone ustawienia zostały zmienione.';es_ES = 'Se han cambiado las configuraciones de aprobación.';es_CO = 'Se han cambiado las configuraciones de aprobación.';tr = 'Onay ayarları değiştirildi.';it = 'Le impostazioni di approvazione sono state modificate.';de = 'Genehmigungseinstellungen sind geändert.'"));
		
	Else
		
		If BackgroundJob <> Undefined Then
			ErrorText = NStr("en = 'Cannot change approval settings.
				|For more details, see the event log.'; 
				|ru = 'Не удалось изменить настройки утверждения.
				|См. подробности в журнале регистрации.';
				|pl = 'Nie można zmienić ustawionych zatwierdzeń.
				|Szczegóły w dzienniku rejestracji.';
				|es_ES = 'No se ha podido cambiar la configuración de la aprobación.
				| Para más detalles, vea el registro de eventos.';
				|es_CO = 'No se ha podido cambiar la configuración de la aprobación.
				| Para más detalles, vea el registro de eventos.';
				|tr = 'Onay ayarları değiştirilemedi.
				|Ayrıntılar için olay günlüğüne bakın.';
				|it = 'Impossibile modificare le impostazioni di approvazione. 
				|Per saperne di più, consultare il registro degli eventi.';
				|de = 'Kann die Genehmigungseinstellungen nicht ändern.
				|Für weitere Informationen siehe Ereignisprotokoll.'");
			CommonClientServer.MessageToUser(ErrorText);
		EndIf;
		
	EndIf;

EndProcedure

&AtServerNoContext
Function ThereAreKitProcessedDocsInBase()
	
	Query = New Query(
	"SELECT TOP 1
	|	Production.Ref AS Ref
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Posted");
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServerNoContext
Function ThereAreKitProcessedWithByProductsDocsInBase()
	
	Query = New Query(
	"SELECT TOP 1
	|	ProductionDisposals.Ref AS Ref
	|FROM
	|	Document.Production.Disposals AS ProductionDisposals
	|		INNER JOIN Document.Production AS Production
	|		ON ProductionDisposals.Ref = Production.Ref
	|WHERE
	|	Production.Posted");
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the PurchaseOrdersStatesCatalog command.
//
&AtClient
Procedure CatalogPurchaseOrderStates(Command)
	
	OpenForm("Catalog.PurchaseOrderStatuses.ListForm");
	
EndProcedure

// Procedure - handler of the PurchaseOrdersStatesCatalog command.
//
&AtClient
Procedure CatalogTransferOrderStates(Command)

	OpenForm("Catalog.TransferOrderStatuses.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogCompanies(Command)

	OpenForm("Catalog.Companies.ListForm");
	
EndProcedure

&AtClient
Procedure EmployeeApprovingPurchases(Command)
	
	OpenForm("InformationRegister.TaskPerformers.Form.PerformersOfRoleWithAddressingObject",
		New Structure("MainAddressingObject, Role",
			Undefined, PredefinedValue("Catalog.PerformerRoles.EmployeeApprovingPurchases")));
			
EndProcedure

&AtClient
Procedure CatalogSubcontractorOrderIssuedStatuses(Command)
	
	OpenForm("Catalog.SubcontractorOrderIssuedStatuses.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogKitOrderStatuses(Command)
	
	OpenForm("Catalog.KitOrderStatuses.ListForm");
	
EndProcedure

&AtClient
Procedure ApplyPurchaseOrdersConditions(Command)
	StartApprovalSettingsInCatalogsChange();
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

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "UseSubcontractorManufacturers" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"CanReceiveSubcontractingServices",
				"Enabled",
				Not Parameter.Value);
			
			CommonClientServer.SetFormItemProperty(Items,
				"DecorationSubcontractorOrderIssuedTooltip",
				"Visible",
				Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - handler of the OnChange event of the UseSeveralUnitsForProduct field.
//
&AtClient
Procedure FunctionalOptionAccountingInVariousUOMOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseCharacteristics field.
//
&AtClient
Procedure FunctionalOptionUseCharacteristicsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the  OnChange event of the UseBatches field.
//
&AtClient
Procedure FunctionalOptionUseBatchesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralWarehouses field.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleWarehousesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the FunctionalOptionUseSerialNumbers field.
//
&AtClient
Procedure FunctionalOptionFunctionalOptionUseSerialNumbersOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the FunctionalOptionUseSerialNumbersAsInventoryRecordDetails field.
//
&AtClient
Procedure FunctionalOptionUseSerialNumbersAsInventoryRecordDetailsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the CatalogBusinessUnitsWarehouses command.
//
&AtClient
Procedure CatalogBusinessUnitsWarehouses(Command)
	
	If ConstantsSet.UseSeveralWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.RetailEarningAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainWarehouse"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure

// Procedure - the OnChange event handler of the UseStorageBins field.
//
&AtClient
Procedure FunctionalOptionAccountingByCellsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UsePurchaseOrderStatuses field.
//
&AtClient
Procedure UsePurchaseOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UsePurchaseOrderStatuses field.
//
&AtClient
Procedure UseTransferOrderStatesOnChange(Item)

	Attachable_OnAttributeChange(Item);
	
EndProcedure


// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusTransferOrderOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CompletedStatus field.
// 
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure CompletedStatusTransferOrderOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionCounterpartiesPricesAccountingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseProductCrossReferencesOnChange(Item)
	
	If Not ConstantsSet.UseProductCrossReferences
		And CheckUseProductCrossReferences() Then
	
		StructureParameters = New Structure("NameConstant, Item", "UseProductCrossReferences", Item);
		Notification = New NotifyDescription("UseProductCrossReferencesOnChangeEnd", ThisObject, StructureParameters);
		
		TextQuestion = NStr("en = 'Product cross-references have already been created.
			|If you continue, they will become unavailable. 
			|Do you want to continue?'; 
			|ru = 'В приложении уже используется номенклатура поставщиков.
			|Если вы продолжите, они станут недоступны.
			|Продолжить?';
			|pl = 'Powiązane informacje o produkcie zostały już utworzone.
			|Jeśli chcesz kontynuować, one będą niedostępne. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Las referencias cruzadas del producto ya han sido creadas. 
			|Si continúa, se convertirán en indisponibles. 
			|¿Quiere continuar?';
			|es_CO = 'Las referencias cruzadas del producto ya han sido creadas. 
			|Si continúa, se convertirán en indisponibles. 
			|¿Quiere continuar?';
			|tr = 'Ürün çapraz referansları zaten oluşturuldu.
			|Devam ederseniz bunlar kullanılamayacak.
			|Devam etmek istiyor musunuz?';
			|it = 'I riferimenti incrociati dell''articolo sono già stati creati. 
			|Continuando non saranno più disponibili. 
			|Continuare?';
			|de = 'Produktherstellartikelnummern wurden bereits erstellt.
			|Wenn Sie fortfahren, werden sie nicht mehr verfügbar sein. 
			|Möchten Sie fortfahren?'"); 
		
		Mode = QuestionDialogMode.YesNo;
		ShowQueryBox(Notification, TextQuestion, Mode, 0);
		
	Else 
		
		Attachable_OnAttributeChange(Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseProductCrossReferencesOnChangeEnd(Result, StructureParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Attachable_OnAttributeChange(StructureParameters.Item);
	Else
		ConstantsSet[StructureParameters.NameConstant] = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UseZeroInvoiceSalesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionIntraCommunityTransfersOnChange(Item)
	
	Attachable_OnAttributeChange(Item);	
	
EndProcedure

&AtClient
Procedure FunctionalOptionPurchaseOrderApprovalOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
	If Not ValueIsFilled(ConstantsSet.PurchaseOrdersApprovalType) Then
		ConstantsSet.PurchaseOrdersApprovalType
			= PredefinedValue("Enum.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty");
	EndIf;
	
EndProcedure

&AtClient
Procedure UseDiscountsInPurchasesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure WeightUOMOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseSeparateApproversForCompaniesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	ChangeEmployeeApprovingPurchases();
	
EndProcedure

&AtClient
Procedure PurchaseOrderApprovalTypeOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure LimitWithoutApprovalOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseSubcontractorOrderIssuedStatusesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure SubcontractorOrderIssuedInProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure SubcontractorOrderIssuedCompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure ReceiveSubcontractingServicesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseAccountPayableAdjustmentsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseOldProductionOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure UseKitOrderStatusesOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure KitOrdersInProgressStatusOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure KitOrdersCompletionStatusOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure UseByProductsInKitProcessingOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#EndRegion
