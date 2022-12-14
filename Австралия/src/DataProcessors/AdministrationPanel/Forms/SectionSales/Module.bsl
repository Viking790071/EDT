
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
			|ru = '???? ?????????????? ?????????? ???????? ????????????. ?????????????? ""????????????"" ?????? ""????????????????"" (???? ????????????)
			|?????? ?????????????????????? ?????? ?????????????? ??????????????????????. ?????????? ?????????? ????????????,
			|???????????????? ?????????????? ???????? ??????????????. ?????? ?????????????? ???? ???????????????? ""????????????""
			|???????????????? ???????????? ???? ""?? ????????????"" ?????? ""????????????????"" (????????????).
			|?????? ?????????????? ???? ???????????????? ""????????????????"" (???? ????????????) ???????????????? ???????????? ???? ""????????????????"" (????????????).
			|?????? ?????????? ???????????????? ????????????.';
			|pl = 'Nie mo??na oczy??ci?? tego pola wyboru. Statusy ""Otwarte"" lub ""Zako??czono"" (nie zamkni??te)
			|s?? ju?? ustawione dla zam??wie?? sprzeda??y. Aby m??c oczy??ci?? pole wyboru,
			|zmie?? statusy tych zam??wie??. Dla zam??wie?? o statusie ""Otwarte"",
			|zmie?? status na ""W toku"" lub ""Zako??czono"" (zamkni??te).
			|Dla zam??wie?? o statusie ""Zako??czono"" (nie zamkni??te), zmie?? status na ""Zako??czono"" (zamkni??te).
			|Aby zrobi?? to, zamknij zam??wienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificaci??n. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya est??n establecidos para las ??rdenes de ventas. Para poder desmarcar la casilla de verificaci??n,
			|cambie los estados de estas ??rdenes. Para las ??rdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las ??rdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las ??rdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificaci??n. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya est??n establecidos para las ??rdenes de ventas. Para poder desmarcar la casilla de verificaci??n,
			|cambie los estados de estas ??rdenes. Para las ??rdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las ??rdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las ??rdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Sat???? sipari??leri i??in ""A????k"" veya ""Tamamland??"" (kapat??lmad??) durumlar?? belirtildi.
			|Onay kutusunu temizleyebilmek i??in bu sipari??lerin durumlar??n?? de??i??tirin.
			|""A????k"" durumundaki sipari??lerin durumlar??n?? ""????lemde"" veya ""Tamamland??"" (kapat??ld??) olarak de??i??tirin.
			|""Tamamland??"" (kapat??lmad??) durumundaki sipari??lerin durumunu ""Tamamland??"" (kapat??ld??) olarak de??i??tirin.
			|Bunu yapmak i??in sipari??leri kapat??n.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completo"" (non chiuso)
			| sono gi?? impostati per gli Ordini cliente. Per poter deselezionare la casella di controllo, 
			|modificare lo stato di questi ordini. Per ordini con stato ""Aperto"", 
			|modificare lo stato in ""In lavorazione"" o ""Completato"" (chiuso). 
			|Per ordini con stato ""Completato"" (non chiuso), modificare lo stato in ""Completato"" (chiuso). 
			|Per fare ci??, chiudere gli ordini.';
			|de = 'Dieses Kontrollk??stchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits f??r Kundenauftr??ge festgelegt. Um das Kontrollk??stchen
			|deaktivieren zu k??nnen, ??ndern Sie die Status dieser Auftr??ge. Bei Auftr??gen mit dem Status ""Offen"",
			|??ndern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Auftr??gen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ??ndern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schlie??en Sie die Auftr??ge.'");
		
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
			ErrorText = NStr("en = 'Discounts are already used in the database. You can''t unmark the checkbox.'; ru = '?? ???????? ?????? ???????????????????????? ????????????. ?????????????????? ???????????? ????????????.';pl = 'Rabaty s?? ju?? u??yte w bazie danych. Nie mo??na odznaczy?? pola wyboru.';es_ES = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificaci??n.';es_CO = 'Descuentos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificaci??n.';tr = 'Veritaban??nda indirimler kullan??mda. Onay kutusu temizlenemez.';it = 'Gli sconti sono gi?? utilizzati nel database. Non potete deselezionare la casella di controllo.';de = 'Rabatte werden bereits in der Datenbank verwendet. Sie k??nnen das Kontrollk??stchen nicht deaktivieren.'");
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
			NStr("en = 'Automatic discounts are already used in the database. You can''t unmark the checkbox.'; ru = '?? ???????? ?????? ???????????????????????? ???????????????????????????? ????????????. ?????????????????? ???????????? ????????????.';pl = 'Rabaty automatyczne s?? ju?? u??yte w bazie danych. Nie mo??na odznaczy?? pola wyboru.';es_ES = 'Descuentos autom??ticos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificaci??n.';es_CO = 'Descuentos autom??ticos ya se utilizan en la base de datos. Usted no puede desmarcar la casilla de verificaci??n.';tr = 'Veritaban??nda otomatik indirimler kullan??mda. Onay kutusu temizlenemez.';it = 'Sconti automatici sono gi?? utilizzati nel database. Non potete deselezionare la casella di controllo.';de = 'Automatische Rabatte werden bereits in der Datenbank verwendet. Sie k??nnen das Kontrollk??stchen nicht deaktivieren.'");
	EndIf;
	
	// DiscountCards
	If GetFunctionalOption("UseDiscountCards") Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'Option ""Use discount cards"" is enabled. You can''t unmark the checkbox.'; ru = '?????????? ""???????????????????????? ???????????????????? ??????????"" ????????????????. ?????????????????? ???????????? ????????????.';pl = 'Opcja ""U??ycie kart rabatowych"" jest w????czona. Nie mo??na odznaczy?? pola wyboru.';es_ES = 'Opci??n ""Utilizar las tarjetas de descuentos"" est?? activada. Usted no puede desmarcar la casilla de verificaci??n.';es_CO = 'Opci??n ""Utilizar las tarjetas de descuentos"" est?? activada. Usted no puede desmarcar la casilla de verificaci??n.';tr = '""??ndirim kartlar??n?? kullan"" se??ene??i etkin. Onay kutusu temizlenemez.';it = 'La opzione ""Utilizzare carte sconto"" ?? abilitata. Non potete deselezionare la casella di controllo.';de = 'Die Option ""Rabattkarten verwenden"" ist aktiviert. Sie k??nnen das Kontrollk??stchen nicht deaktivieren.'");
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
		
		ErrorText = NStr("en = 'There are movements or objects related to the retail sale transaction accounting in the infobase. Cannot clear the check box.'; ru = '?? ???????? ???????? ???????????????? ?????? ??????????????, ?????????????????????? ?? ?????????? ???????????????? ?????????????????? ????????????! ???????????? ?????????? ??????????????????!';pl = 'W bazie informacyjnej istniej?? przemieszczenia lub obiekty, zwi??zane z ksi??gowaniem transakcji sprzeda??y detalicznej. Nie mo??na odznaczy?? tego pola wyboru.';es_ES = 'Hay movimientos u objetos relacionados con la contabilidad de las transacciones de ventas minoristas en la infobase. No se puede vaciar la casilla de verificaci??n.';es_CO = 'Hay movimientos u objetos relacionados con la contabilidad de las transacciones de ventas minoristas en la infobase. No se puede vaciar la casilla de verificaci??n.';tr = 'Infobase''de perakende sat???? i??lemiyle ilgili hareketler veya nesneler var. Onay kutusu temizlenemiyor.';it = 'Ci sono movimenti o oggetti correlati alla contabilit?? delle transazioni della vendita al dettaglio nell''infobase. Impossibile deselezionare la casella di controllo.';de = 'Es gibt Bewegungen oder Objekte im Zusammenhang mit der Transaktion des Einzelhandelsverkaufs in der Infobase. Das Kontrollk??stchen kann nicht gel??scht werden.'");
		
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
		
		ErrorText = NStr("en = 'You cannot disable ""Reservation"" once used.'; ru = '?????? ?????????????? ?? ?????????????? ?????????????? ???????????? ???????????????????? ?????????? ""????????????????????????????"" ????????????????????.';pl = 'Po u??yciu nie mo??na wy????czy?? opcji ""Rezerwacja"".';es_ES = 'No se puede desactivar ""Reserva"" una vez utilizado.';es_CO = 'No se puede desactivar ""Reserva"" una vez utilizado.';tr = '""Rezervasyon"" kulland??ktan sonra devre d?????? b??rak??lamaz.';it = 'Non potete disabilitare ""Riserve"" una volta usate.';de = 'Sie k??nnen die ""Reservierung"", die einmal verwendet wurde, nicht mehr deaktivieren.'");
		
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
		ErrorText = NStr("en = 'Cannot clear this check box. Product bundles are registered in the Products catalog.'; ru = '???? ?????????????? ?????????????????? ??????????. ?? ?????????????????????? ???????????????????????? ?????? ?????????????? ?????????????????? ????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Zestawy produkt??w s?? zarejestrowane w katalogu Produkty.';es_ES = 'No puedo desmarcar esta casilla de verificaci??n. Los paquetes de productos est??n registrados en el cat??logo de productos.';es_CO = 'No puedo desmarcar esta casilla de verificaci??n. Los paquetes de productos est??n registrados en el cat??logo de productos.';tr = 'Bu onay kutusu temizlenemiyor. ??r??n katalo??unda ??r??n setleri kay??tl??.';it = 'Impossibile deselezionare questa casella di controllo. I kit di prodotti sono registrati nel catalogo Articoli.';de = 'Dieses Kontrollk??stchen kann nicht deaktiviert werden. Artikelgruppen sind im Produktkatalog registriert.'");
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
			ErrorText = NStr("en = 'Cannot turn automatic discounts off because they are already applied to some documents.'; ru = '???????????????????? ?????????????????? ???????????????????????????? ????????????, ?????? ?????? ?????? ?????? ?????????????????? ?? ?????????????????? ????????????????????.';pl = 'Nie mo??na wy????czy?? automatycznych rabat??w, poniewa?? s?? one ju?? stosowane do niekt??rych dokument??w.';es_ES = 'No se puede desactivar los descuentos autom??ticos porque ya se aplican a algunos documentos.';es_CO = 'No se puede desactivar los descuentos autom??ticos porque ya se aplican a algunos documentos.';tr = 'Otomatik indirimler baz?? belgelere uyguland??????ndan kapat??lam??yor.';it = 'Impossibile disattivare gli sconti automatici poich?? sono gi?? applicati ad altri documenti.';de = 'Automatische Rabatte k??nnen nicht deaktiviert werden, da sie auf einige Dokumente angewendet werden.'");
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
				NStr("en = 'Cannot turn automatic discounts off because they are already applied to some documents.'; ru = '???????????????????? ?????????????????? ???????????????????????????? ????????????, ?????? ?????? ?????? ?????? ?????????????????? ?? ?????????????????? ????????????????????.';pl = 'Nie mo??na wy????czy?? automatycznych rabat??w, poniewa?? s?? one ju?? stosowane do niekt??rych dokument??w.';es_ES = 'No se puede desactivar los descuentos autom??ticos porque ya se aplican a algunos documentos.';es_CO = 'No se puede desactivar los descuentos autom??ticos porque ya se aplican a algunos documentos.';tr = 'Otomatik indirimler baz?? belgelere uyguland??????ndan kapat??lam??yor.';it = 'Impossibile disattivare gli sconti automatici poich?? sono gi?? applicati ad altri documenti.';de = 'Automatische Rabatte k??nnen nicht deaktiviert werden, da sie auf einige Dokumente angewendet werden.'");
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
			
			ErrorText = NStr("en = 'Discount cards are used in the infobase. Cannot clear the check box.'; ru = '?? ???????? ???????????????????????? ???????????????????? ??????????! ???????????? ?????????? ??????????????????!';pl = 'W bazie informacyjnej u??ywane s?? karty rabatowe. Nie mo??na odznaczy?? pola wyboru.';es_ES = 'Tarjetas de descuentos se utilizan en la infobase. No se puede vaciar la casilla de verificaci??n.';es_CO = 'Tarjetas de descuentos se utilizan en la infobase. No se puede vaciar la casilla de verificaci??n.';tr = 'Infobase''de indirim kartlar?? kullan??mda. Onay kutusu temizlenemez.';it = 'Il database utilizza Carte sconto! La rimozione dell''opzione ?? vietata!';de = 'Rabattkarten werden in der Infobase verwendet. Das Kontrollk??stchen kann nicht gel??scht werden.'");
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
			|ru = '???????????? ?????????????????? ?????????? ""???????????????????????????? ?????????????? ?? ????????????????????"", ?????? ??????
			|?????????????? ???????????????????? ?????????? ?? ?????????????????? ?????????????????????????? ?????????????????????? ??????????????????????????.';
			|pl = 'Nie mo??esz wy????czy?? opcji Dostosuj nale??no??ci poniewa??
			|istniej?? Noty kredytowe z operacj?? korekty nale??no??ci.';
			|es_ES = 'No puede desactivar la opci??n Ajustar cuentas por cobrar porque
			|hay notas de cr??dito con la operaci??n de ajustes de cuentas por cobrar.';
			|es_CO = 'No puede desactivar la opci??n Ajustar cuentas por cobrar porque
			|hay notas de cr??dito con la operaci??n de ajustes de cuentas por cobrar.';
			|tr = '''Alacak hesaplar??n?? d??zelt'' se??ene??i devre d?????? b??rak??lam??yor ????nk??
			|Alacak hesaplar??n?? d??zeltme i??lemi olan Alacak dekontlar?? var.';
			|it = 'Impossibile disabilitare l''opzione Correzione crediti contabili poich??
			| vi sono Note di credito con l''operazione Correzione crediti contabili.';
			|de = 'Sie k??nnen die Option ???Offene Posten Debitoren korrigieren??? nicht deaktivieren, 
			|da Belastungen mit der Operation ???Korrekturen von Offenen Posten Debitoren??? vorhanden sind.'");
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
			|ru = '???? ?????????????? ?????????? ????????????. 
			|?????????????? ?????????????????????? ???????????????? ???????? ?????? ????????????????????????????????.';
			|pl = 'Nie mo??na wyczy??ci?? pola wyboru. 
			|Faktury sprzeda??y z zerowym typem faktury s?? ju?? zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificaci??n. 
			|Las facturas de venta con un tipo de factura con importe cero ya est??n registradas.';
			|es_CO = 'No se puede desmarcar la casilla de verificaci??n. 
			|Las facturas de venta con un tipo de factura con importe cero ya est??n registradas.';
			|tr = 'Onay kutusu temizlenemedi. 
			|S??f??r bedelli fatura t??r?? sat???? faturalar?? zaten kaydedildi.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|Le fatture di vendita con tipo Fattura a zero sono gi?? state registrate.';
			|de = 'Das Kontrollk??stchen kann nicht deaktiviert werden. 
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
		
		ErrorText = NStr("en = 'Cannot clear the check box. Closing invoices are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ???????????????????????????? ?????????????? ?????? ????????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Faktury ko??cowe s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. Las facturas de cierre ya est??n registradas.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. Las facturas de cierre ya est??n registradas.';tr = 'Onay kutusu temizlenemiyor. Kay??tl?? kapan???? faturalar?? mevcut.';it = 'Impossibile deselezionare la casella di controllo. Le fatture di chiusura sono gi?? registrate.';de = 'Kann das Kontrollk??stchen nicht deaktivieren. Abschlussrechnungen sind bereits registriert.'");
		
	ElsIf Not Results[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box. Actual sales volume are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ?????????????????????? ?????????? ???????????? ?????? ??????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Rzeczywista wielko???? sprzeda??y jest ju?? zarejestrowana.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. El volumen real de ventas ya est?? registrado.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. El volumen real de ventas ya est?? registrado.';tr = 'Onay kutusu temizlenemiyor. Kay??tl?? Ger??ekle??en sat???? hacmi var.';it = 'Impossibile deselezionare la casella di controllo. I volumi effettivi di vendita sono gi?? registrati.';de = 'Kann das Kontrollk??stchen nicht deaktivieren. Aktuelle Verkaufsmengen sind bereits registriert.'");
		
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
						|ru = '???? ?????????????? ?????????? ????????????.
						|?????????????????? ?? ???????????????? ?????? ???????????????????????? ?????? ????????????????????????????????.';
						|pl = 'Nie mo??na wyczy??ci?? tego pola wyboru.
						|Dokumenty z towarami do dropshippingu s?? ju?? zarejestrowane.';
						|es_ES = 'No se puede desmarcar la casilla de verificaci??n.
						|Los documentos con las mercanc??as para el env??o directo ya est??n registrados.';
						|es_CO = 'No se puede desmarcar la casilla de verificaci??n.
						|Los documentos con las mercanc??as para el env??o directo ya est??n registrados.';
						|tr = 'Onay kutusu temizlenemiyor.
						|Stoksuz sat???? ??r??nleri i??eren belgeler zaten kaydedildi.';
						|it = 'Impossibile deselezionare la casella di controllo.
						| I documenti con merci in dropshipping sono gi?? stati registrati.';
						|de = 'Fehler beim Deaktivieren des Kontrollk??stchens.
						|Die Dokumente mit Waren f??r Streckengesch??ft sind bereits registriert.'");
		
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
			|ru = '???? ?????????????? ?????????? ????????????. 
			|???????????????????? ???????????? ???? ?????????????????????? ?????? ????????????????????????????????.';
			|pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. 
			|Otrzymane zam??wienia podwykonawcy s?? ju?? zarejestrowane.';
			|es_ES = 'No se puede desmarcar la casilla de verificaci??n. 
			|Las ??rdenes recibidas del subcontratista ya est??n registradas.';
			|es_CO = 'No se puede desmarcar la casilla de verificaci??n. 
			|Las ??rdenes recibidas del subcontratista ya est??n registradas.';
			|tr = 'Onay kutusu temizlenemiyor. 
			|Kay??tl?? Al??nan alt y??klenici sipari??leri var.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			|Gli ordini di subfornitura ricevuti sono gi?? registrati.';
			|de = 'Kann das Kontrollk??stchen nicht deaktivieren. 
			|Subunternehmerauftr??ge erhalten sind bereits registriert.'");
		
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
			|ru = '???? ?????????????? ?????????? ???????? ????????????. ?????????????? ""????????????"" ?????? ""????????????????"" (???? ????????????)
			|?????? ?????????????????????? ?????? ???????????????????? ?????????????? ???? ??????????????????????. ?????????? ?????????? ???????? ????????????,
			|???????????????? ?????????????? ???????? ??????????????. ?????? ?????????????? ???? ???????????????? ""????????????"",
			|???????????????? ???????????? ???? ""?? ????????????"" ?????? ""????????????????"" (????????????).
			|?????? ?????????????? ???? ???????????????? ""????????????????"" (???? ????????????), ???????????????? ???????????? ???? ""????????????????"" (????????????).
			|?????? ?????????? ???????????????? ????????????.';
			|pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Statusy ""Otwarte"" lub ""Zako??czono"" (nie zamkni??te)
			|s?? ju?? ustawione dla otrzymanych zam??wie?? podwykonawcy. Aby m??c wyczy??ci?? pole wyboru,
			|zmie?? statusy tych zam??wie??. Dla zam??wie?? o statusie ""Otwarte"",
			|zmie?? status na ""W toku"" lub ""Zako??czono"" (zamkni??te).
			|Dla zam??wie?? o statusie ""Zako??czono"" (nie zamkni??te), zmie?? status na ""Zako??czono"" (zamkni??te).
			|Aby zrobi?? to, zamknij zam??wienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificaci??n. Los Estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya est??n establecidos para las ??rdenes recibidas del Subcontratista. Para poder desmarcar la casilla de verificaci??n,
			|cambie los estados de estas ??rdenes. Para las ??rdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las ??rdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las ??rdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificaci??n. Los Estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya est??n establecidos para las ??rdenes recibidas del Subcontratista. Para poder desmarcar la casilla de verificaci??n,
			|cambie los estados de estas ??rdenes. Para las ??rdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las ??rdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las ??rdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Al??nan alt y??klenici sipari??leri i??in ""A????k"" veya ""Tamamland??"" (kapat??lmad??) durumlar?? belirtildi.
			|Onay kutusunu temizleyebilmek i??in bu sipari??lerin durumlar??n?? de??i??tirin.
			|""A????k"" durumundaki sipari??lerin durumlar??n?? ""????lemde"" veya ""Tamamland??"" (kapat??ld??) olarak de??i??tirin.
			|""Tamamland??"" (kapat??lmad??) durumundaki sipari??lerin durumunu ""Tamamland??"" (kapat??ld??) olarak de??i??tirin.
			|Bunu yapmak i??in sipari??leri kapat??n.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono gi?? impostati per gli Ordini di subfornitura ricevuti. Per poter deselezionare la casella di controllo,
			|modificare lo stato di tali ordini. Per gli ordini con stato ""Aperto"", 
			|modificare lo stato a ""In corso"" o ""Completato"" (chiuso).
			| per gli ordini con stato ""Completato"" (non chiuso), modificare lo stato a ""Completato"" (chiuso).
			| Per fare ci??, ?? necessario chiudere gli ordini.';
			|de = 'Dieses Kontrollk??stchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits f??r Subunternehmerauftr??ge erhalten festgelegt. Um das Kontrollk??stchen
			|deaktivieren zu k??nnen, ??ndern Sie die Status dieser Auftr??ge. Bei Auftr??gen mit dem Status ""Offen"",
			|schalten Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen) um.
			|Bei Auftr??gen mit dem Status ""Abgeschlossen"" (nicht geschlossen) schalten Sie den Status zu ""Abgeschlossen"" (geschlossen) um.
			|Um dies zu tun, schlie??en Sie die Auftr??ge.'");
		
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
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = '???? ?????????????? ???????????????? ???????????????????? ""%1"". ??????????????????: %2';pl = 'Nie mo??na zapisa?? katalogu ""%1"". Szczeg????y: %2';es_ES = 'Ha ocurrido un error al guardar el cat??logo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el cat??logo ""%1"". Detalles: %2';tr = '""%1"" katalo??u saklanam??yor. Ayr??nt??lar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				Catalogs.Counterparties.RetailCustomer,
				BriefErrorDescription(ErrorInfo()));
				
		WriteLogEvent(
			NStr("en = 'Update catalog Counterparties'; ru = '???????????????????? ?????????????????????? ??????????????????????';pl = 'Aktualizj katalog Kontahenci';es_ES = 'Actualizaci??n del cat??logo Contrapartes';es_CO = 'Actualizaci??n del cat??logo Contrapartes';tr = 'Cari hesaplar katalo??unu g??ncelle';it = 'Aggiornare catalogo Controparti';de = 'Katalog ""Gesch??ftspartner"" aktualisieren'", CommonClientServer.DefaultLanguageCode()),
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
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'; ru = '???????? ???????? ""???????????????????????? ?????????????????? ???????????????? ?????????????? ??????????????????????"", ???? ???? ???????????????? ???????????????? ?????????????? ""?? ????????????"".';pl = 'Pole wyboru ""U??yj kilku stan??w zam??wie?? sprzeda??y"" jest oczyszczone, ale parametr ""W toku"" nie jest wype??niony.';es_ES = 'La casilla de verificaci??n ""Utilizar varios estados de ??rdenes de ventas"" est?? vaciada pero el par??metro del estado ""En progreso"" no est?? rellenado.';es_CO = 'La casilla de verificaci??n ""Utilizar varios estados de ??rdenes de ventas"" est?? vaciada pero el par??metro del estado ""En progreso"" no est?? rellenado.';tr = '""Birka?? sat???? sipari??i durumu kullan"" onay kutusu temizlendi, ancak ""Devam ediyor"" durumu parametresi doldurulmad??.';it = 'La casella di controllo ""Utilizzare diversi stati ordine cliente"" non ?? selezionatato, ma il parametro di stato ""In lavorazione"" non ?? stato compilato.';de = 'Das Kontrollk??stchen ""Mehrere Zust??nde von Kundenuftrag verwenden"" ist zwar deaktiviert, aber der Statusparameter ""In Bearbeitung"" ist nicht ausgef??llt.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.SalesOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedSalesOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'; ru = '???????? ???????? ""???????????????????????? ?????????????????? ???????????????? ?????????????? ??????????????????????"", ???? ???? ???????????????? ???????????????? ?????????????? ""????????????????""!';pl = 'Pole wyboru ""U??ycie kilku stan??w zam??wienia sprzeda??y"" jest oczyszczone, ale parametr ""Zako??czono"" nie zosta?? wype??niony.';es_ES = 'La casilla de verificaci??n ""Utilizar varios estados de ??rdenes de ventas"" est?? vaciada pero el par??metro del estado ""Finalizado"" no est?? rellenado.';es_CO = 'La casilla de verificaci??n ""Utilizar varios estados de ??rdenes de ventas"" est?? vaciada pero el par??metro del estado ""Finalizado"" no est?? rellenado.';tr = '""Birka?? sat???? sipari??i durumu kullan"" onay kutusu temizlendi, ancak ""Tamamland??"" durumu parametresi doldurulmad??.';it = 'La casella di controllo ""Utilizzare diversi stati ordine clienti"" non ?? selezionata, ma il parametro di stato ""Completato"" non ?? compilato.';de = 'Das Kontrollk??stchen ""Mehrere Zust??nde von Kundenuftrag verwenden"" ist deaktiviert, aber der Statusparameter ""Abgeschlossen"" ist nicht ausgef??llt.'");
			
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