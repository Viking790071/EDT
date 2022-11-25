#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	List.Parameters.SetParameterValue("UserSetting",
		ChartsOfCharacteristicTypes.UserSettings["StatusOfNewSubcontractorOrderIssued"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSettingsChanged" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
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

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandSetMainItem(Command)
	
	SelectedItem = Items.List.CurrentRow;
	
	If ValueIsFilled(SelectedItem) Then
		DriveServer.SetUserSetting(SelectedItem, "StatusOfNewSubcontractorOrderIssued");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	FontMainSetting = StyleFonts.FontDialogAndMenu;
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("MainSetting");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontMainSetting);
	
EndProcedure

#EndRegion