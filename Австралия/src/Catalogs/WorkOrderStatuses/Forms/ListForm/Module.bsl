#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Selection of main item
	List.Parameters.SetParameterValue("UserSetting", ChartsOfCharacteristicTypes.UserSettings["StatusOfNewWorkOrder"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
	PaintList();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
// Procedure - event handler NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSettingsChanged" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnActivateRow.
//
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	MainSetting = Items.List.CurrentData.MainSetting;
	
	If MainSetting Then
		Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'; ru = 'Используется для создания новых заказов';pl = 'Służy do tworzenia nowych zamówień';es_ES = 'Solía crear nuevas órdenes';es_CO = 'Solía crear nuevas órdenes';tr = 'Yeni siparişler oluşturmak için kullanılır';it = 'Utilizzato per creare nuovi ordini';de = 'Wird verwendet, um neue Aufträge zu erstellen'");
		Items.FormCommandSetMainItem.Enabled = False;
	Else
		Items.FormCommandSetMainItem.Title = "";
		Items.FormCommandSetMainItem.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
	
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		DriveServer.SetUserSetting(SelectedItem, "StatusOfNewWorkOrder");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

// Procedure colors the list.
//
&AtServer
Procedure PaintList()
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("MainSetting");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Order is canceled'; ru = 'Заказ отменен';pl = 'Zamówienie zostało odwołane';es_ES = 'Orden cancelada';es_CO = 'Orden cancelada';tr = 'Sipariş iptal edildi';it = 'L''ordine è stato cancellato';de = 'Auftrag wird storniert'");
	
EndProcedure

#EndRegion