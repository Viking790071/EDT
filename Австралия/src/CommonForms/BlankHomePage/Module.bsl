
#Region EventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	If Not StandardSubsystemsClient.ApplicationStartupLogicDisabled() Then
		Return;
	EndIf;
	
	Items.TestMode.Visible = True;
	
	TestModeTitle = "{" + NStr("ru = 'Тестирование'; en = 'Testing'; pl = 'Testowanie';es_ES = 'Prueba';es_CO = 'Prueba';tr = 'Test';it = 'Facendo test';de = 'Testen'") + "} ";
	CurrentTitle = ClientApplication.GetCaption();
	
	If StrStartsWith(CurrentTitle, TestModeTitle) Then
		Return;
	EndIf;
	
	ClientApplication.SetCaption(TestModeTitle + CurrentTitle);
	
	RegisterApplicationStartupLogicDisabling();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure RegisterApplicationStartupLogicDisabling()
	
	SetPrivilegedMode(True);
	
	DataOwner = Catalogs.MetadataObjectIDs.GetRef(
		New UUID("627a6fb8-872a-11e3-bb87-005056c00008")); // Constants
	
	DisablingDates = Common.ReadDataFromSecureStorage(DataOwner);
	If TypeOf(DisablingDates) <> Type("Array") Then
		DisablingDates = New Array;
	EndIf;
	
	DisablingDates.Add(CurrentSessionDate());
	Common.WriteDataToSecureStorage(DataOwner, DisablingDates);
	
EndProcedure

#EndRegion
