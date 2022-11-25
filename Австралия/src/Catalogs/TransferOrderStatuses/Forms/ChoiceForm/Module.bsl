#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	// Selection of main item	
	List.Parameters.SetParameterValue("UserSetting", ChartsOfCharacteristicTypes.UserSettings["StatusOfNewTransferOrder"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
	SetFormConditionalAppearance();
	
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
	
	MainSetting = Items.List.CurrentData.MainSetting;
	
	If MainSetting Then
		Items.FormCommandSetMainItem.Title = Nstr("en = 'Used to create new orders'; ru = 'Используется для создания новых заказов';pl = 'Służy do tworzenia nowych zamówień';es_ES = 'Solía crear nuevas órdenes';es_CO = 'Solía crear nuevas órdenes';tr = 'Yeni siparişler oluşturmak için kullanılır';it = 'Utilizzato per creare nuovi ordini';de = 'Wird verwendet, um neue Aufträge zu erstellen'");
		Items.FormCommandSetMainItem.Enabled = False;
	Else
		Items.FormCommandSetMainItem.Title = "";
		Items.FormCommandSetMainItem.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		DriveServer.SetUserSetting(SelectedItem, "StatusOfNewTransferOrder");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFormConditionalAppearance()
	
	// InventoryCostOfGoodsSold
	NewConditionalAppearance = List.ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"MainSetting",
		True,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font( , , True));
	
EndProcedure

#EndRegion
