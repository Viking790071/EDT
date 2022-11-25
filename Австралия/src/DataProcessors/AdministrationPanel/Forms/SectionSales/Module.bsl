
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
	
	If AttributePathToData = "ConstantsSet.UseRetail" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "Group1", 							"Enabled", ConstantsSet.UseRetail);
		CommonClientServer.SetFormItemProperty(Items, "SettingAccountingRetailSalesDetails","Enabled", ConstantsSet.UseRetail);
		CommonClientServer.SetFormItemProperty(Items, "Group2", 							"Enabled", ConstantsSet.UseRetail);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "CatalogSalesOrderStates",			"Enabled", ConstantsSet.UseSalesOrderStatuses);
		CommonClientServer.SetFormItemProperty(Items, "SalesOrdersDefaultStatusSetting","Enabled", Not ConstantsSet.UseSalesOrderStatuses);
		
	EndIf;
	
	// DiscountCards
	If AttributePathToData = "ConstantsSet.UseManualDiscounts" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "UseDiscountCards", "Enabled", ConstantsSet.UseManualDiscounts);
		
	EndIf;
	// End DiscountCards
	
	If AttributePathToData = "ConstantsSet.UseKanbanForQuotations" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "CatalogQuotationStatuses", "Enabled", ConstantsSet.UseKanbanForQuotations);
		
	EndIf;
	
	If AttributePathToData = "" Then
		
		UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
		
		CommonClientServer.SetFormItemProperty(Items,
		"IssueClosingInvoices",
		"Enabled",
		UseContractsWithCounterparties);
		
		CommonClientServer.SetFormItemProperty(Items,
		"DecorationEnableClosingInvoices",
		"Visible",
		Not UseContractsWithCounterparties);
		
		CommonClientServer.SetFormItemProperty(Items, "SubcontractingServicesSettings", "Visible", Not GetFunctionalOption("DriveTrade"));
		// begin Drive.FullVersion
		CommonClientServer.SetFormItemProperty(Items, "SubcontractingServicesSettings", "Enabled", GetFunctionalOption("UseProductionSubsystem"));
		// end Drive.FullVersion

		UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
		
		CommonClientServer.SetFormItemProperty(Items,
		"IssueClosingInvoices",
		"Enabled",
		UseContractsWithCounterparties);
		
		CommonClientServer.SetFormItemProperty(Items,
		"DecorationEnableClosingInvoices",
		"Visible",
		Not UseContractsWithCounterparties);
		
	EndIf;
	
	// begin Drive.FullVersion
	
	If AttributePathToData = "ConstantsSet.CanProvideSubcontractingServices"
		Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items,
		"SubcontractorOrderReceivedSeveralStatuses",
		"Visible",
		ConstantsSet.CanProvideSubcontractingServices);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseSubcontractorOrderReceivedStatuses"
		Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items,
		"SubcontractorOrderReceivedStatuses",
		"Enabled",
		Not ConstantsSet.UseSubcontractorOrderReceivedStatuses);
		
		CommonClientServer.SetFormItemProperty(Items,
		"CatalogSubcontractorOrderReceivedStatuses",
		"Enabled",
		ConstantsSet.UseSubcontractorOrderReceivedStatuses);
		
	EndIf;
	
	// end Drive.FullVersion 
	
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
	
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses Then
			
			If Not ValueIsFilled(ConstantsSet.SalesOrdersInProgressStatus)
				OR ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
				
				UpdateSalesOrderStatesOnChange();
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseRetail" Then
		
		UpdateRetailCustomer(ConstantsSet.UseRetail);
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		ConstantsSet.UseSalesOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		ConstantsSet.SalesOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		ConstantsSet.StateCompletedSalesOrders = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseManualDiscounts" Then
		
		ConstantsSet.UseManualDiscounts = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SendGoodsOnConsignment" Then
		
		ConstantsSet.SendGoodsOnConsignment = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AcceptConsignedGoods" Then
		
		ConstantsSet.AcceptConsignedGoods = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseRetail" Then
		
		ConstantsSet.UseRetail = CurrentValue;
		
	// DiscountCards
	ElsIf AttributePathToData = "ConstantsSet.UseDiscountCards" Then
		
		ConstantsSet.UseDiscountCards = CurrentValue;
		
	// End DiscountCards 
	// AutomaticDiscounts
	ElsIf AttributePathToData = "ConstantsSet.UseAutomaticDiscounts" Then
		
		ConstantsSet.UseAutomaticDiscounts = CurrentValue;
		
	// End AutomaticDiscounts
	ElsIf AttributePathToData = "ConstantsSet.UseInventoryReservation" Then
		
		ConstantsSet.UseInventoryReservation = CurrentValue;
		
	// Bundles
	ElsIf AttributePathToData = "ConstantsSet.UseProductBundles" Then
		
		ConstantsSet.UseProductBundles = CurrentValue;
	// End Bundles
	ElsIf AttributePathToData = "ConstantsSet.UseAccountReceivableAdjustments" Then
		
		ConstantsSet.UseAccountReceivableAdjustments = CurrentValue;
		
		
	ElsIf AttributePathToData = "ConstantsSet.UseZeroInvoiceSales" Then
		
		ConstantsSet.UseZeroInvoiceSales = CurrentValue;
	
	ElsIf AttributePathToData = "ConstantsSet.IssueClosingInvoices" Then
		
		ConstantsSet.IssueClosingInvoices = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseDropShipping" Then
		
		ConstantsSet.UseDropShipping = CurrentValue;
		
	// begin Drive.FullVersion
	
	ElsIf AttributePathToData = "ConstantsSet.CanProvideSubcontractingServices" Then
		
		ConstantsSet.CanProvideSubcontractingServices = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractorOrderReceivedStatuses" Then
		
		ConstantsSet.UseSubcontractorOrderReceivedStatuses = CurrentValue;
		
	// end Drive.FullVersion 
		
	EndIf;
	
EndProcedure

// Check the possibility to disable the UseSalesOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseSalesOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SalesOrder.Ref AS Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	(SalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR SalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT SalesOrder.Closed
	|				AND (SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForSale)
	|					OR SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)))";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Sales orders. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Open"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для заказов покупателей. Чтобы снять флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт""
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт) измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można oczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla zamówień sprzedaży. Aby móc oczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de ventas. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de ventas. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Satış siparişleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu siparişlerin durumlarını değiştirin.
			|""Açık"" durumundaki siparişlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki siparişlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için siparişleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completo"" (non chiuso)
			| sono già impostati per gli Ordini cliente. Per poter deselezionare la casella di controllo, 
			|modificare lo stato di questi ordini. Per ordini con stato ""Aperto"", 
			|modificare lo stato in ""In lavorazione"" o ""Completato"" (chiuso). 
			|Per ordini con stato ""Completato"" (non chiuso), modificare lo stato in ""Completato"" (chiuso). 
			|Per fare ciò, chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Kundenaufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseManualDiscounts option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountsMarkups()
	
	ErrorText = "";
	SetPrivilegedMode(True);
	
	SelectionDiscountTypes = Catalogs.DiscountTypes.Select();
	While SelectionDiscountTypes.Next() Do
		RefArray = New Array;
		RefArray.Add(SelectionDiscountTypes.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			ErrorText = NStr("en = 'Discounts are already used in the database. You can''t unmark the checkbox.'; ru = 'В базе уже используются скидки. Отключить флажок нельзя.';pl = 'Rabaty są już użyte w bazie danych. Nie można odznaczyć pola wyboru.';es_ES = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';es_CO = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';tr = 'Veritabanında indirimler kullanımda. Onay kutusu temizlenemez.';it = 'Gli sconti sono già utilizzati nel database. Non potete deselezionare la casella di controllo.';de = 'Rabatte werden bereits in der Datenbank verwendet. Sie können das Kontrollkästchen nicht deaktivieren.'");
			Break;
		EndIf;
	EndDo;
	
	SetPrivilegedMode(False);
	
	ArrayOfDocuments = New Array;

	ArrayOfDocuments.Add("Document.SalesOrder.Inventory");
	ArrayOfDocuments.Add("Document.SalesOrder.Works");
	ArrayOfDocuments.Add("Document.ShiftClosure.Inventory");
	ArrayOfDocuments.Add("Document.SalesInvoice.Inventory");
	ArrayOfDocuments.Add("Document.Quote.Inventory");
	ArrayOfDocuments.Add("Document.SalesSlip.Inventory");
	ArrayOfDocuments.Add("Document.ProductReturn.Inventory");
	
	QueryPattern = 
	"SELECT TOP 1
	|	CWT_Of_Document.Ref AS Ref
	|FROM
	|	&DocumentTabularSection AS CWT_Of_Document
	|WHERE
	|	CWT_Of_Document.DiscountMarkupPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement In ArrayOfDocuments Do
		If Not IsBlankString(Query.Text) Then
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
		EndIf;
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +
			NStr("en = 'Automatic discounts are already used in the database. You can''t unmark the checkbox.'; ru = 'В базе уже используются автоматические скидки. Отключить флажок нельзя.';pl = 'Rabaty automatyczne są już użyte w bazie danych. Nie można odznaczyć pola wyboru.';es_ES = 'Descuentos automáticos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';es_CO = 'Descuentos automáticos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificación.';tr = 'Veritabanında otomatik indirimler kullanımda. Onay kutusu temizlenemez.';it = 'Sconti automatici sono già utilizzati nel database. Non potete deselezionare la casella di controllo.';de = 'Automatische Rabatte werden bereits in der Datenbank verwendet. Sie können das Kontrollkästchen nicht deaktivieren.'");
	EndIf;
	
	// DiscountCards
	If GetFunctionalOption("UseDiscountCards") Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'Option ""Use discount cards"" is enabled. You can''t unmark the checkbox.'; ru = 'Опция ""Использовать дисконтные карты"" включена. Отключить флажок нельзя.';pl = 'Opcja ""Użycie kart rabatowych"" jest włączona. Nie można odznaczyć pola wyboru.';es_ES = 'Opción ""Utilizar las tarjetas de descuentos"" está activada. Usted no puede desmarcar la casilla de verificación.';es_CO = 'Opción ""Utilizar las tarjetas de descuentos"" está activada. Usted no puede desmarcar la casilla de verificación.';tr = '""İndirim kartlarını kullan"" seçeneği etkin. Onay kutusu temizlenemez.';it = 'La opzione ""Utilizzare carte sconto"" è abilitata. Non potete deselezionare la casella di controllo.';de = 'Die Option ""Rabattkarten verwenden"" ist aktiviert. Sie können das Kontrollkästchen nicht deaktivieren.'");
	EndIf;
	// End DiscountCards
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseRetail option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingRetail()
	
	ErrorText = "";
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	SUM(ISNULL(AccumulationRegisters.RecordersCount, 0)) AS RecordersCount
	|FROM
	|	(SELECT
	|		COUNT(AccumulationRegister.Recorder) AS RecordersCount
	|	FROM
	|		AccumulationRegister.ProductRelease AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.IncomeAndExpenses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.Inventory AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.CashInCashRegisters AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.POSSummary AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(Catalog.Ref)
	|	FROM
	|		Catalog.BusinessUnits AS Catalog
	|	WHERE
	|		(Catalog.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|				OR Catalog.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting))) AS AccumulationRegisters";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next()
		AND QuerySelection.RecordersCount > 0 Then
		
		ErrorText = NStr("en = 'There are movements or objects related to the retail sale transaction accounting in the infobase. Cannot clear the check box.'; ru = 'В базе есть движения или объекты, относящиеся к учету операций розничных продаж! Снятие флага запрещено!';pl = 'W bazie informacyjnej istnieją przemieszczenia lub obiekty, związane z księgowaniem transakcji sprzedaży detalicznej. Nie można odznaczyć tego pola wyboru.';es_ES = 'Hay movimientos u objetos relacionados con la contabilidad de las transacciones de ventas minoristas en la infobase. No se puede vaciar la casilla de verificación.';es_CO = 'Hay movimientos u objetos relacionados con la contabilidad de las transacciones de ventas minoristas en la infobase. No se puede vaciar la casilla de verificación.';tr = 'Infobase''de perakende satış işlemiyle ilgili hareketler veya nesneler var. Onay kutusu temizlenemiyor.';it = 'Ci sono movimenti o oggetti correlati alla contabilità delle transazioni della vendita al dettaglio nell''infobase. Impossibile deselezionare la casella di controllo.';de = 'Es gibt Bewegungen oder Objekte im Zusammenhang mit der Transaktion des Einzelhandelsverkaufs in der Infobase. Das Kontrollkästchen kann nicht gelöscht werden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the InventoryReservation option.
//
&AtServer
Function CancellationUncheckFunctionalOptionInventoryReservation()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ReservedProducts.SalesOrder AS SalesOrder
	|FROM
	|	AccumulationRegister.ReservedProducts AS ReservedProducts
	|WHERE
	|	ReservedProducts.SalesOrder <> UNDEFINED";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'You cannot disable ""Reservation"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Резервирование"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Rezerwacja"".';es_ES = 'No se puede desactivar ""Reserva"" una vez utilizado.';es_CO = 'No se puede desactivar ""Reserva"" una vez utilizado.';tr = '""Rezervasyon"" kullandıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Riserve"" una volta usate.';de = 'Sie können die ""Reservierung"", die einmal verwendet wurde, nicht mehr deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#Region Bundles

// Check on the possibility to disable the UseProductBundles option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseProductBundles()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Products.Ref AS Ref
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	NOT Products.DeletionMark
		|	AND Products.IsBundle";
	
	RefsTable = Query.Execute().Unload();
	
	If RefsTable.Count() > 0 Then
		ErrorText = NStr("en = 'Cannot clear this check box. Product bundles are registered in the Products catalog.'; ru = 'Не удается отключить опцию. В справочнике Номенклатура уже созданы комплекты номенклатуры.';pl = 'Nie można wyczyścić tego pola wyboru. Zestawy produktów są zarejestrowane w katalogu Produkty.';es_ES = 'No puedo desmarcar esta casilla de verificación. Los paquetes de productos están registrados en el catálogo de productos.';es_CO = 'No puedo desmarcar esta casilla de verificación. Los paquetes de productos están registrados en el catálogo de productos.';tr = 'Bu onay kutusu temizlenemiyor. Ürün kataloğunda ürün setleri kayıtlı.';it = 'Impossibile deselezionare questa casella di controllo. I kit di prodotti sono registrati nel catalogo Articoli.';de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Artikelgruppen sind im Produktkatalog registriert.'");
	EndIf;
		
	Return ErrorText;
	
EndFunction

#EndRegion

#Region AutomaticDiscounts

// Check on the possibility to disable the UseAutomaticDiscounts option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups()
	
	ErrorText = "";
	SetPrivilegedMode(True);
	
	SelectionAutomaticDiscounts = Catalogs.AutomaticDiscountTypes.Select();
	While SelectionAutomaticDiscounts.Next() Do
		RefArray = New Array;
		RefArray.Add(SelectionAutomaticDiscounts.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			ErrorText = NStr("en = 'Cannot turn automatic discounts off because they are already applied to some documents.'; ru = 'Невозможно отключить автоматические скидки, так как они уже применены к некоторым документам.';pl = 'Nie można wyłączyć automatycznych rabatów, ponieważ są one już stosowane do niektórych dokumentów.';es_ES = 'No se puede desactivar los descuentos automáticos porque ya se aplican a algunos documentos.';es_CO = 'No se puede desactivar los descuentos automáticos porque ya se aplican a algunos documentos.';tr = 'Otomatik indirimler bazı belgelere uygulandığından kapatılamıyor.';it = 'Impossibile disattivare gli sconti automatici poiché sono già applicati ad altri documenti.';de = 'Automatische Rabatte können nicht deaktiviert werden, da sie auf einige Dokumente angewendet werden.'");
			Break;
		EndIf;
	EndDo;
	
	SetPrivilegedMode(False);
	
	If IsBlankString(ErrorText) Then
		
		ArrayOfDocuments = New Array;
		ArrayOfDocuments.Add("Document.SalesOrder.Inventory");
		ArrayOfDocuments.Add("Document.SalesOrder.Works");
		ArrayOfDocuments.Add("Document.ShiftClosure.Inventory");
		ArrayOfDocuments.Add("Document.SalesInvoice.Inventory");
		ArrayOfDocuments.Add("Document.Quote.Inventory");
		ArrayOfDocuments.Add("Document.SalesSlip.Inventory");
		ArrayOfDocuments.Add("Document.ProductReturn.Inventory");
		
		QueryPattern =
		"SELECT TOP 1
		|	CWT_Of_Document.Ref AS Ref
		|FROM
		|	&DocumentTabularSection AS CWT_Of_Document
		|WHERE
		|	CWT_Of_Document.AutomaticDiscountsPercent <> 0";
		
		Query = New Query;
		
		For Each ArrayElement In ArrayOfDocuments Do
			If Not IsBlankString(Query.Text) Then
				Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
			EndIf;
			Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
		EndDo;
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +
				NStr("en = 'Cannot turn automatic discounts off because they are already applied to some documents.'; ru = 'Невозможно отключить автоматические скидки, так как они уже применены к некоторым документам.';pl = 'Nie można wyłączyć automatycznych rabatów, ponieważ są one już stosowane do niektórych dokumentów.';es_ES = 'No se puede desactivar los descuentos automáticos porque ya se aplican a algunos documentos.';es_CO = 'No se puede desactivar los descuentos automáticos porque ya se aplican a algunos documentos.';tr = 'Otomatik indirimler bazı belgelere uygulandığından kapatılamıyor.';it = 'Impossibile disattivare gli sconti automatici poiché sono già applicati ad altri documenti.';de = 'Automatische Rabatte können nicht deaktiviert werden, da sie auf einige Dokumente angewendet werden.'");
		EndIf;
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#EndRegion

#Region DiscountCards

// Check on the possibility to uncheck the UseDiscountCards option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountCards()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	SelectionDiscountCards = Catalogs.DiscountCards.Select();
	While SelectionDiscountCards.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionDiscountCards.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Discount cards are used in the infobase. Cannot clear the check box.'; ru = 'В базе используются дисконтные карты! Снятие опции запрещено!';pl = 'W bazie informacyjnej używane są karty rabatowe. Nie można odznaczyć pola wyboru.';es_ES = 'Tarjetas de descuentos se utilizan en la infobase. No se puede vaciar la casilla de verificación.';es_CO = 'Tarjetas de descuentos se utilizan en la infobase. No se puede vaciar la casilla de verificación.';tr = 'Infobase''de indirim kartları kullanımda. Onay kutusu temizlenemez.';it = 'Il database utilizza Carte sconto! La rimozione dell''opzione è vietata!';de = 'Rabattkarten werden in der Infobase verwendet. Das Kontrollkästchen kann nicht gelöscht werden.'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction

#EndRegion

&AtServer
Function CancellationUncheckUseAccountReceivableAdjustments()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CreditNote.Ref AS Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	NOT CreditNote.DeletionMark
	|	AND CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.Adjustments)";
	
	If Not Query.Execute().IsEmpty() Then
		ErrorText = NStr("en = 'You cannot disable Adjust accounts receivable option because
			|there are Credit notes with the Accounts receivable adjustments operation.'; 
			|ru = 'Нельзя отключить опцию ""Корректировать расчеты с дебиторами"", так как
			|имеются кредитовые авизо с операцией корректировки дебиторской задолженности.';
			|pl = 'Nie możesz wyłączyć opcji Dostosuj należności ponieważ
			|istnieją Noty kredytowe z operacją korekty należności.';
			|es_ES = 'No puede desactivar la opción Ajustar cuentas por cobrar porque
			|hay notas de crédito con la operación de ajustes de cuentas por cobrar.';
			|es_CO = 'No puede desactivar la opción Ajustar cuentas por cobrar porque
			|hay notas de crédito con la operación de ajustes de cuentas por cobrar.';
			|tr = '''Alacak hesaplarını düzelt'' seçeneği devre dışı bırakılamıyor çünkü
			|Alacak hesaplarını düzeltme işlemi olan Alacak dekontları var.';
			|it = 'Impossibile disabilitare l''opzione Correzione crediti contabili poiché
			| vi sono Note di credito con l''operazione Correzione crediti contabili.';
			|de = 'Sie können die Option „Offene Posten Debitoren korrigieren“ nicht deaktivieren, 
			|da Belastungen mit der Operation „Korrekturen von Offenen Posten Debitoren“ vorhanden sind.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

#Region ZeroInvoice

// Check on the possibility to uncheck the UseZeroInvoiceSales option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseZeroInvoiceSales()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SalesInvoice.Ref AS Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ZeroInvoice)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. 
			|Sales invoices with a zero invoice type are already registered.'; 
			|ru = 'Не удается снять флажок. 
			|Инвойсы покупателям нулевого типа уже зарегистрированы.';
			|pl = 'Nie można wyczyścić pola wyboru. 
			|Faktury sprzedaży z zerowym typem faktury są już zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificación. 
			|Las facturas de venta con un tipo de factura con importe cero ya están registradas.';
			|es_CO = 'No se puede desmarcar la casilla de verificación. 
			|Las facturas de venta con un tipo de factura con importe cero ya están registradas.';
			|tr = 'Onay kutusu temizlenemedi. 
			|Sıfır bedelli fatura türü satış faturaları zaten kaydedildi.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|Le fatture di vendita con tipo Fattura a zero sono già state registrate.';
			|de = 'Das Kontrollkästchen kann nicht deaktiviert werden. 
			|Verkaufsrechnungen mit dem Rechnungstyp Null sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

#EndRegion

&AtServer
Function CancellationUncheckFunctionalOptionIssueClosingInvoices()
	
	SetPrivilegedMode(True);
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ActualSalesVolume.Ref AS Ref
	|FROM
	|	Document.ActualSalesVolume AS ActualSalesVolume
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SalesInvoice.Ref AS Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice)";
	
	Results = Query.ExecuteBatch();
	
	If Not Results[1].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. Closing invoices are already registered.'; ru = 'Не удается снять флажок. Заключительные инвойсы уже зарегистрированы.';pl = 'Nie można wyczyścić tego pola wyboru. Faktury końcowe są już zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificación. Las facturas de cierre ya están registradas.';es_CO = 'No se puede desmarcar la casilla de verificación. Las facturas de cierre ya están registradas.';tr = 'Onay kutusu temizlenemiyor. Kayıtlı kapanış faturaları mevcut.';it = 'Impossibile deselezionare la casella di controllo. Le fatture di chiusura sono già registrate.';de = 'Kann das Kontrollkästchen nicht deaktivieren. Abschlussrechnungen sind bereits registriert.'");
		
	ElsIf Not Results[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. Actual sales volume are already registered.'; ru = 'Не удается снять флажок. Фактический объем продаж уже зарегистрирован.';pl = 'Nie można wyczyścić tego pola wyboru. Rzeczywista wielkość sprzedaży jest już zarejestrowana.';es_ES = 'No se puede desmarcar la casilla de verificación. El volumen real de ventas ya está registrado.';es_CO = 'No se puede desmarcar la casilla de verificación. El volumen real de ventas ya está registrado.';tr = 'Onay kutusu temizlenemiyor. Kayıtlı Gerçekleşen satış hacmi var.';it = 'Impossibile deselezionare la casella di controllo. I volumi effettivi di vendita sono già registrati.';de = 'Kann das Kontrollkästchen nicht deaktivieren. Aktuelle Verkaufsmengen sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckFunctionalOptionUseDropShipping()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SalesOrderInventory.Ref AS Ref
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.DropShipping";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox.
						|The documents with goods for drop shipping are already registered.'; 
						|ru = 'Не удалось снять флажок.
						|Документы с товарами для дропшиппинга уже зарегистрированы.';
						|pl = 'Nie można wyczyścić tego pola wyboru.
						|Dokumenty z towarami do dropshippingu są już zarejestrowane.';
						|es_ES = 'No se puede desmarcar la casilla de verificación.
						|Los documentos con las mercancías para el envío directo ya están registrados.';
						|es_CO = 'No se puede desmarcar la casilla de verificación.
						|Los documentos con las mercancías para el envío directo ya están registrados.';
						|tr = 'Onay kutusu temizlenemiyor.
						|Stoksuz satış ürünleri içeren belgeler zaten kaydedildi.';
						|it = 'Impossibile deselezionare la casella di controllo.
						| I documenti con merci in dropshipping sono già stati registrati.';
						|de = 'Fehler beim Deaktivieren des Kontrollkästchens.
						|Die Dokumente mit Waren für Streckengeschäft sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

// begin Drive.FullVersion

// Check the possibility to disable the UseSubcontractorOrdersReceived option.
//
&AtServer
Function CancellationUncheckUseSubcontractorOrdersReceived()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SubcontractorOrderReceived.Ref AS Ref
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. 
			|Subcontractor orders received are already registered.'; 
			|ru = 'Не удается снять флажок. 
			|Полученные заказы на переработку уже зарегистрированы.';
			|pl = 'Nie można wyczyścić tego pola wyboru. 
			|Otrzymane zamówienia podwykonawcy są już zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificación. 
			|Las órdenes recibidas del subcontratista ya están registradas.';
			|es_CO = 'No se puede desmarcar la casilla de verificación. 
			|Las órdenes recibidas del subcontratista ya están registradas.';
			|tr = 'Onay kutusu temizlenemiyor. 
			|Kayıtlı Alınan alt yüklenici siparişleri var.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|Gli ordini di subfornitura ricevuti sono già registrati.';
			|de = 'Kann das Kontrollkästchen nicht deaktivieren. 
			|Subunternehmeraufträge erhalten sind bereits registriert.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseSalesOrderReceivedStatuses option.
//
&AtServer
Function CancellationUncheckUseUseSubcontractorOrderReceivedStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SubcontractorOrderReceived.Ref AS Ref
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|WHERE
	|	(SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT SubcontractorOrderReceived.Closed)";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Subcontractor orders received. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Open"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для полученных заказов на переработку. Чтобы снять этот флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт"",
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт), измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można wyczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla otrzymanych zamówień podwykonawcy. Aby móc wyczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los Estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes recibidas del Subcontratista. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los Estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes recibidas del Subcontratista. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Alınan alt yüklenici siparişleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu siparişlerin durumlarını değiştirin.
			|""Açık"" durumundaki siparişlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki siparişlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için siparişleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono già impostati per gli Ordini di subfornitura ricevuti. Per poter deselezionare la casella di controllo,
			|modificare lo stato di tali ordini. Per gli ordini con stato ""Aperto"", 
			|modificare lo stato a ""In corso"" o ""Completato"" (chiuso).
			| per gli ordini con stato ""Completato"" (non chiuso), modificare lo stato a ""Completato"" (chiuso).
			| Per fare ciò, è necessario chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Subunternehmeraufträge erhalten festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|schalten Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen) um.
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) schalten Sie den Status zu ""Abgeschlossen"" (geschlossen) um.
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// end Drive.FullVersion

// Procedure updates the parameters of the sales order status.
//
&AtServerNoContext
Procedure UpdateSalesOrderStatesOnChange()
	
	InProcessStatus = Constants.SalesOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedSalesOrders.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	SalesOrderStatuses.Ref AS State
		|FROM
		|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|WHERE
		|	SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.SalesOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	SalesOrderStatuses.Ref AS State
		|FROM
		|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|WHERE
		|	SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.StateCompletedSalesOrders.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure

// Procedure updates predefined item RetailCustomer
//
&AtServerNoContext
Procedure UpdateRetailCustomer(UseRetail)
	
	ObjectRetailCustomer = Catalogs.Counterparties.RetailCustomer.GetObject();
	ObjectRetailCustomer.DoNotShow = (Not UseRetail);
	
	Try
	
		ObjectRetailCustomer.Write();
	
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Catalogs.Counterparties.RetailCustomer,
				BriefErrorDescription(ErrorInfo()));
				
		WriteLogEvent(
			NStr("en = 'Update catalog Counterparties'; ru = 'Обновление справочника Контрагенты';pl = 'Aktualizj katalog Kontahenci';es_ES = 'Actualización del catálogo Contrapartes';es_CO = 'Actualización del catálogo Contrapartes';tr = 'Cari hesaplar kataloğunu güncelle';it = 'Aggiornare catalogo Controparti';de = 'Katalog ""Geschäftspartner"" aktualisieren'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Counterparties,
			,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are Sales orders with the status which differs from Complete, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		If Constants.UseSalesOrderStatuses.Get() <> ConstantsSet.UseSalesOrderStatuses
			AND (NOT ConstantsSet.UseSalesOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseSalesOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the SalesOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.SalesOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько статусов заказов покупателей"", но не заполнен параметр статуса ""В работе"".';pl = 'Pole wyboru ""Użyj kilku stanów zamówień sprzedaży"" jest oczyszczone, ale parametr ""W toku"" nie jest wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes de ventas"" está vaciada pero el parámetro del estado ""En progreso"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes de ventas"" está vaciada pero el parámetro del estado ""En progreso"" no está rellenado.';tr = '""Birkaç satış siparişi durumu kullan"" onay kutusu temizlendi, ancak ""Devam ediyor"" durumu parametresi doldurulmadı.';it = 'La casella di controllo ""Utilizzare diversi stati ordine cliente"" non è selezionatato, ma il parametro di stato ""In lavorazione"" non è stato compilato.';de = 'Das Kontrollkästchen ""Mehrere Zustände von Kundenuftrag verwenden"" ist zwar deaktiviert, aber der Statusparameter ""In Bearbeitung"" ist nicht ausgefüllt.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.SalesOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedSalesOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько статусов заказов покупателей"", но не заполнен параметр статуса ""Завершен""!';pl = 'Pole wyboru ""Użycie kilku stanów zamówienia sprzedaży"" jest oczyszczone, ale parametr ""Zakończono"" nie został wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes de ventas"" está vaciada pero el parámetro del estado ""Finalizado"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes de ventas"" está vaciada pero el parámetro del estado ""Finalizado"" no está rellenado.';tr = '""Birkaç satış siparişi durumu kullan"" onay kutusu temizlendi, ancak ""Tamamlandı"" durumu parametresi doldurulmadı.';it = 'La casella di controllo ""Utilizzare diversi stati ordine clienti"" non è selezionata, ma il parametro di stato ""Completato"" non è compilato.';de = 'Das Kontrollkästchen ""Mehrere Zustände von Kundenuftrag verwenden"" ist deaktiviert, aber der Statusparameter ""Abgeschlossen"" ist nicht ausgefüllt.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedSalesOrders.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are any references to discounts kinds in the documents, it is not allowed to remove the UseManualDiscounts flag
	If AttributePathToData = "ConstantsSet.UseManualDiscounts" Then
	
		If Constants.UseManualDiscounts.Get() <> ConstantsSet.UseManualDiscounts 
			AND (NOT ConstantsSet.UseManualDiscounts) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any register records, containing the retail structural unit, it is not allowed to remove the UseRetail flag
	If AttributePathToData = "ConstantsSet.UseRetail" Then
	
		If Constants.UseRetail.Get() <> ConstantsSet.UseRetail
			AND (NOT ConstantsSet.UseRetail) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingRetail();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// DiscountCards
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the
	// UseDiscountCards flag
	If AttributePathToData = "ConstantsSet.UseDiscountCards" Then
	
		If Constants.UseDiscountCards.Get() <> ConstantsSet.UseDiscountCards 
			AND (NOT ConstantsSet.UseDiscountCards) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountCards();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End DiscountCards
	
	// AutomaticDiscounts
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the
	// UseAutomaticDiscounts flag
	If AttributePathToData = "ConstantsSet.UseAutomaticDiscounts" Then
	
		If Constants.UseAutomaticDiscounts.Get() <> ConstantsSet.UseAutomaticDiscounts 
			AND (NOT ConstantsSet.UseAutomaticDiscounts) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End AutomaticDiscounts
	
	// If there are any movements in register "Inventory" for the non-empty sales order, the clearing of  the
	// UseInventoryReservation check box is prohibited
	If AttributePathToData = "ConstantsSet.UseInventoryReservation" Then
		
		If Constants.UseInventoryReservation.Get() <> ConstantsSet.UseInventoryReservation 
			AND (NOT ConstantsSet.UseInventoryReservation) Then
			
			ErrorText = CancellationUncheckFunctionalOptionInventoryReservation();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Bundles
	If AttributePathToData = "ConstantsSet.UseProductBundles" Then
		
		If Constants.UseProductBundles.Get() <> ConstantsSet.UseProductBundles
			AND (NOT ConstantsSet.UseProductBundles) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseProductBundles();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End Bundles
	
	If AttributePathToData = "ConstantsSet.UseAccountReceivableAdjustments" Then
		
		If Not ConstantsSet.UseAccountReceivableAdjustments
			And Constants.UseAccountReceivableAdjustments.Get() <> ConstantsSet.UseAccountReceivableAdjustments Then
			
			ErrorText = CancellationUncheckUseAccountReceivableAdjustments();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck UseZeroInvoiceSales.
	If AttributePathToData = "ConstantsSet.UseZeroInvoiceSales" Then
		
		If Constants.UseZeroInvoiceSales.Get() <> ConstantsSet.UseZeroInvoiceSales
			And (Not ConstantsSet.UseZeroInvoiceSales) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseZeroInvoiceSales();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck IssueClosingInvoices.
	If AttributePathToData = "ConstantsSet.IssueClosingInvoices" Then
		
		If Constants.IssueClosingInvoices.Get() <> ConstantsSet.IssueClosingInvoices
			And (Not ConstantsSet.IssueClosingInvoices) Then
			
			ErrorText = CancellationUncheckFunctionalOptionIssueClosingInvoices();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck UseDropShipping.
	If AttributePathToData = "ConstantsSet.UseDropShipping" Then
		
		If Constants.UseDropShipping.Get() <> ConstantsSet.UseDropShipping
			And (Not ConstantsSet.UseDropShipping) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDropShipping();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// begin Drive.FullVersion
	
	// If there are Subcontractor orders received, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.CanProvideSubcontractingServices" Then
		
		If Constants.CanProvideSubcontractingServices.Get() <> ConstantsSet.CanProvideSubcontractingServices
			And (Not ConstantsSet.CanProvideSubcontractingServices) Then
			
			ErrorText = CancellationUncheckUseSubcontractorOrdersReceived();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are Subcontractor orders received with the status which differs from Complete, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseSubcontractorOrderReceivedStatuses" Then
		
		If Constants.UseSubcontractorOrderReceivedStatuses.Get() <> ConstantsSet.UseSubcontractorOrderReceivedStatuses
			AND (NOT ConstantsSet.UseSubcontractorOrderReceivedStatuses) Then
			
			ErrorText = CancellationUncheckUseUseSubcontractorOrderReceivedStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// end Drive.FullVersion 
	
EndFunction

#EndRegion

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CatalogCashRegisters.
//
&AtClient
Procedure CatalogCashRegisters(Command)
	
	OpenForm("Catalog.CashRegisters.ListForm");
	
EndProcedure

// Procedure - command handler CatalogPOSTerminals.
//
&AtClient
Procedure CatalogPOSTerminals(Command)
	
	OpenForm("Catalog.POSTerminals.ListForm");
	
EndProcedure

// Procedure - command handler CatalogSalesOrderStates.
//
&AtClient
Procedure CatalogSalesOrderStates(Command)
	
	OpenForm("Catalog.SalesOrderStatuses.ListForm");
	
EndProcedure

// Procedure - command handler CatalogQuotationStatuses.
//
&AtClient
Procedure CatalogQuotationStatuses(Command)
	
	OpenForm("Catalog.QuotationStatuses.ListForm");
	
EndProcedure

// Procedure - command handler SubcontractingOrderReceivedStatuses.
//
&AtClient
Procedure CatalogSubcontractingOrderReceivedStatuses(Command)
	
	OpenForm("Catalog.SubcontractorOrderReceivedStatuses.ListForm");
	
EndProcedure

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
		
		If Source = "UseContractsWithCounterparties" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"IssueClosingInvoices",
				"Enabled",
				Parameter.Value);
			
			CommonClientServer.SetFormItemProperty(Items,
				"DecorationEnableClosingInvoices",
				"Visible",
				Not Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the UseRetail field.
//
&AtClient
Procedure FunctionalOptionAccountingRetailOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the ArchiveSalesSlipsDuringTheShiftClosure field.
//
&AtClient
Procedure ArchiveCRReceiptsOnCloseCashCRSessionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the DeleteNonIssuedSalesSlips field.
//
&AtClient
Procedure DeleteUnpinnedChecksOnCloseCashRegisterShiftsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CheckStockBalanceWhenIssuingSalesSlips field.
//
&AtClient
Procedure ControlBalancesDuringCreationCRReceiptsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseKanbanForQuotations field.
//
&AtClient
Procedure UseKanbanForQuotationsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseSalesOrderStatuses field.
//
&AtClient
Procedure UseSalesOrderStatusesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseZeroInvoiceSalesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure IssueClosingInvoicesOnChange(Item)
	
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

// Procedure - event handler OnChange of the SendGoodsOnConsignment field
//
&AtClient
Procedure FunctionalOptionTransferGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the AcceptConsignedGoods field.
//
&AtClient
Procedure FunctionalOptionReceiveGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseManualDiscounts field.
//
&AtClient
Procedure FunctionalOptionUseDiscountsMarkupsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseProjects field.
//
&AtClient
Procedure FunctionalOptionAccountingByProjectsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseInventoryReservation field.
//
&AtClient
Procedure FunctionalOptionInventoryReservationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseProductBundlesOnChange field.
//
&AtClient
Procedure UseProductBundlesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseAccountReceivableAdjustmentsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure ProvideSubcontractingServicesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseSubcontractorOrderReceivedStatusesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure SubcontractorOrdersReceivedInProgressStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure SubcontractorOrdersReceivedCompletionStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDropShippingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#Region DiscountCards

// Procedure - event handler OnChange of the UseDiscountCards field.
//
&AtClient
Procedure FunctionalOptionFunctionalOptionUseDiscountCardsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndRegion