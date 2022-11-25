
#Region FormEventHandlers

&AtServer
// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Constants.KitProcessingUpdateWasCompleted.Get() = False Then
		CommonClientServer.MessageToUser(
		NStr("en = '1C:Drive update is not completed. It required to install the Kit processing updates. If you have Administrator rights, open the All functions menu and run the Kit processing update installer. Otherwise, contact the 1C:Drive administrator with the request to install the updates.'; ru = 'Обновление 1C:Drive не завершено. Требуется установить обновления обработки комплектации. Если у вас есть права администратора, откройте меню Все функции и запустите Программу установки обновления обработки комплектации. В противном случае обратитесь к администратору 1C:Drive с просьбой установить обновления.';pl = 'Aktualizacja 1C:Drive nie jest zakończona. Wymagane jest zainstalowanie aktualizacji przetwarzania zestawu. Jeśli masz uprawnienia Administratora, otwórz menu ""Wszystkie funkcje"" i uruchom instalator aktualizacji przetwarzania zestawu. W przeciwnym razie, skontaktuj się z administratorem 1C:Drive z zapytaniem o instalację aktualizacji.';es_ES = 'La actualización de 1C:Drive no se ha finalizado. Es necesario instalar las actualizaciones de procesamiento del kit. Si tiene derechos de Administrador, abra el menú Todas las funciones y ejecute el instalador de la actualización del procesamiento del kit. De lo contrario, póngase en contacto con el administrador de 1C:Drive para solicitar la instalación de las actualizaciones.';es_CO = 'La actualización de 1C:Drive no se ha finalizado. Es necesario instalar las actualizaciones de procesamiento del kit. Si tiene derechos de Administrador, abra el menú Todas las funciones y ejecute el instalador de la actualización del procesamiento del kit. De lo contrario, póngase en contacto con el administrador de 1C:Drive para solicitar la instalación de las actualizaciones.';tr = '1C:Drive güncellemesi tamamlanmadı. Set işleme güncellemelerinin yüklenmesi gerekiyor. Yönetici yetkilerine sahipseniz Tüm işlevler menüsünü açıp Set işleme güncellemesi yükleyiciyi çalıştırın. Yetkiniz yoksa 1C:Drive yöneticisinden güncellemeleri yüklemesini talep edin.';it = 'L''aggiornamento di 1C:Drive non è completato. Viene richiesta l''installazione degli aggiornamenti dell''elaborazione del Kit. In caso di possesso dei diritti di Amministratore, aprire il menu Tutte le funzioni ed eseguire il programma di installazione degli aggiornamenti dell''elaboratore del Kit. Altrimenti, contattare l''amministratore di 1C:Drive per richiedere l''installamento degli aggiornamenti.';de = '1C:Drive-Update ist nicht abgeschlossen. Updates for Kit-Bearbeitung müssen installiert werden. Sollen Sie Administratorrechte haben, öffnen Sie das Menü ""Alle Funktionen"" und starten den Installateur für Kit-Bearbeitungs-Update. Ansonsten kontaktieren Sie den 1C:Drive-Administrator mit einer Anfrage um Installations von den Updates.'"),
		,,,
		Cancel);
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(ListKitOrders, "StatusInProcess", NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'"));
	CommonClientServer.SetDynamicListParameter(ListKitOrders, "StatusCompleted", NStr("en = 'Completed'; ru = 'Завершен';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	CommonClientServer.SetDynamicListParameter(ListKitOrders, "StatusCanceled", NStr("en = 'Canceled'; ru = 'Отменен';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Annullato';de = 'Abgebrochen'"));
	
	UseStatuses = Constants.UseKitOrderStatuses.Get();
	
	// Use the states of kit orders.
	If UseStatuses Then
		Items.ListKitOrdersOrderStatus.Visible = False;
	Else
		Items.ListProductionOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterDepartment 		= Settings.Get("FilterDepartment");
	FilterResponsible 		= Settings.Get("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
	DriveClientServer.SetListFilterItem(ListKitOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListKitOrders, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	DriveClientServer.SetListFilterItem(ListKitOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_Production" Then
		Items.ListKitOrders.Refresh();
	EndIf;
	
	If EventName = "Record_KitOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListKitOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	DriveClientServer.SetListFilterItem(ListKitOrders, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ListKitOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListKitOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("KitOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
// Procedure - button click handler CreateProduction.
//
Procedure CreateProduction(Command)
	
	If Items.ListKitOrders.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.ListKitOrders.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.Production.ObjectForm", OpenParameters);
		
	Else
		
		ArrayProduction = GenerateProductionDocumentsAndWrite(OrdersArray);
		Text = NStr("en = 'Created:'; ru = 'Создание:';pl = 'Utworzony:';es_ES = 'Creado:';es_CO = 'Creado:';tr = 'Oluşturuldu:';it = 'Creato:';de = 'Erstellt:'");
		For Each RowProduction In ArrayProduction Do
			
			ShowUserNotification(Text, GetURL(RowProduction), RowProduction, PictureLib.Information32);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListKitOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ListKitOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseKitOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.KitOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.KitOrdersCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.KitOrderStatuses.Select();
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
		
		ConditionalAppearanceItem = ListKitOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By order state " + SelectionOrderStatuses.Description;
		
	EndDo;
	
	If PaintByState Then
		
		ConditionalAppearanceItem = ListKitOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	Else
		
		ConditionalAppearanceItem = ListKitOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is canceled";
		
	EndIf;
	
EndProcedure

&AtServer
// Function calls document filling data processor on basis.
//
Function GenerateProductionDocumentsAndWrite(OrdersArray)
	
	ArrayProduction = New Array();
	For Each RowFTS In OrdersArray Do
		
		NewDocumentProduction = Documents.Production.CreateDocument();
		
		NewDocumentProduction.Date = CurrentSessionDate();
		NewDocumentProduction.Fill(RowFTS);
		
		NewDocumentProduction.Write();
		ArrayProduction.Add(NewDocumentProduction.Ref);
		
	EndDo;
	
	Items.List.Refresh();
	
	Return ArrayProduction;
	
EndFunction

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Items.List);
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion