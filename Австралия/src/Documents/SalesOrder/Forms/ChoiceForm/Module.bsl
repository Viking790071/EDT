
#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting And Parameters.Property("GLExpenseAccount") Then
		
		If ValueIsFilled(Parameters.GLExpenseAccount) Then
			
			If Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
				And Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
				And Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress
				And Parameters.GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
				
				MessageText = NStr("en = 'There is no need to specify a Sales order for this GL account.'; ru = 'Для данного типа счета заказ покупателя не указывается.';pl = 'Nie ma potrzeby określania zamówienia sprzedaży dla tego konta księgowego.';es_ES = 'No hay necesidad para especificar el orden de Ventas para esta cuenta del libro mayor.';es_CO = 'No hay necesidad para especificar el orden de Ventas para esta cuenta del libro mayor.';tr = 'Bu muhasebe hesabı için Satış siparişi belirtmek gerekmiyor.';it = 'Non è necessario specificare un ordine Cliente per questo conto mastro.';de = 'Für dieses Hauptbuch-Konto muss kein Kundenauftrag angegeben werden.'");
				DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
				
			EndIf;
			
		Else
			
			MessageText = NStr("en = 'Please select a GL account.'; ru = 'Не выбран счет!';pl = 'Wybierz konto księgowe.';es_ES = 'Por favor, seleccione una cuenta del libro mayor.';es_CO = 'Por favor, seleccione una cuenta del libro mayor.';tr = 'Lütfen, muhasebe hesabı seçin.';it = 'Si prega di selezionare un conto mastro.';de = 'Bitte wählen Sie ein Hauptbuch-Konto aus.'");
			DriveServer.ShowMessageAboutError(, MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
	StatusesStructure = Documents.SalesOrder.GetSalesOrderStringStatuses();
	
	For Each Item In StatusesStructure Do
		CommonClientServer.SetDynamicListParameter(List, Item.Key, Item.Value);
	EndDo;
	
	SetConditionalAppearance();
	
	PaintList();
	
	// Use sales order status.
	If Constants.UseSalesOrderStatuses.Get() Then
		Items.OrderStatus.Visible = False;
	Else
		Items.OrderState.Visible = False;
	EndIf;
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	DriveServer.OverrideStandartGeneratePackingSlipCommand(ThisObject);
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_SalesOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	NotifyChoice(Value);
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region Private

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = NStr("en = 'Order is closed'; ru = 'Заказ закрыт';pl = 'Zamówienie zamknięte';es_ES = 'Pedido está cerrado';es_CO = 'Pedido está cerrado';tr = 'Sipariş kapalı';it = 'Ordine è chiuso';de = 'Auftrag ist abgeschlossen'") Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseSalesOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.SalesOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.StateCompletedSalesOrders.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SalesOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = StatusesStructure.StatusInProcess;
			Else
				FilterItem.RightValue = StatusesStructure.StatusCompleted;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'By lifecycle status'; ru = 'По статусу документа';pl = 'Wg statusu dokumentu';es_ES = 'Por estado del ciclo de vida';es_CO = 'Por estado del ciclo de vida';tr = 'Yaşam döngüsü durumuna göre';it = 'Per stato del ciclo di vita';de = 'Nach Status von Lebenszyklus'") + " " + SelectionOrderStatuses.Description;
		
	EndDo;
	
	If PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'Order is closed'; ru = 'Заказ закрыт';pl = 'Zamówienie zamknięte';es_ES = 'Pedido está cerrado';es_CO = 'Pedido está cerrado';tr = 'Sipariş kapalı';it = 'Ordine è chiuso';de = 'Auftrag ist abgeschlossen'");
		
	Else
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = StatusesStructure.StatusCanceled;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'Order is canceled'; ru = 'Заказ отменен';pl = 'Zamówienie zostało odwołane';es_ES = 'Orden cancelada';es_CO = 'Orden cancelada';tr = 'Sipariş iptal edildi';it = 'L''ordine è stato cancellato';de = 'Auftrag wird storniert'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	FontClosed = New Font(StyleFonts.FontDialogAndMenu,,,False,,,True);
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Closed");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontClosed);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnSalesOrder(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesOrder(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GeneratePackingSlip(Command)
	DriveClient.PackingSlipGenerationBasedOnSalesOrder(Items.List);
EndProcedure

#EndRegion