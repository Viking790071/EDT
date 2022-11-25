#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	List.QueryText = StrReplace(List.QueryText, "%Predefined%", NStr("en = 'Supplied with Aplication'; ru = 'Поставляемый в составе Конфигурации';pl = 'W zestawie z aplikacją';es_ES = 'Proporcionado con la Aplicación';es_CO = 'Proporcionado con la Aplicación';tr = 'Uygulama ile sağlanır';it = 'Fornito come Applicazione';de = 'Geliefert mit Anwendung'"));
	List.QueryText = StrReplace(List.QueryText, "%Attachable%", NStr("en = 'Connected according to the 1C:Compatible standard'; ru = 'Подключаемый по стандарту 1С:Совместимо';pl = 'Podłączony zgodnie ze standardem 1C:Compatible';es_ES = 'Conectado según 1C:Estándar compatible';es_CO = 'Conectado según 1C:Estándar compatible';tr = '1C:Uyumlu standarda uygun olarak bağlandı';it = 'Collegati secondo lo standard """"1C:Compatibile""""';de = 'Anschluss nach dem 1C:Kompatibel Standard'"));
	
	PossibilityToAddNewDrivers = EquipmentManagerServerCallOverridable.PossibilityToAddNewDrivers(); 
	Items.ListCreate.Visible = PossibilityToAddNewDrivers;
	Items.ListCopy.Visible = PossibilityToAddNewDrivers;
	Items.ListContextMenuCreate.Visible = PossibilityToAddNewDrivers;
	Items.ListContextMenuCopy.Visible = PossibilityToAddNewDrivers;
	Items.AddNewDriverFromFile.Visible = PossibilityToAddNewDrivers;
	
	GroupItem = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("TypeDriver");
	GroupItem.Use = True;
	
	GroupItem = List.Group.Items.Add(Type("DataCompositionGroupField"));
	GroupItem.Field = New DataCompositionField("EquipmentType");
	GroupItem.Use = True;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure DriverFileChoiceEnd(FullFileName, Parameters) Export
	
	If Not IsBlankString(FullFileName) Then
		FormParameters = New Structure("FullFileName", FullFileName);
		OpenForm("Catalog.HardwareDrivers.ObjectForm", FormParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddNewDriverFromFile(Command)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en = 'This functionality is available only in the thin and thick client mode.'; ru = 'Данный функционал доступен только в режиме тонкого и толстого клиента.';pl = 'Ta funkcja jest dostępna tylko w trybie cienkiego i grubego klienta.';es_ES = 'Esta funcionalidad está disponible solo en el modo de cliente ligero y el cliente pesado.';es_CO = 'Esta funcionalidad está disponible solo en el modo de cliente ligero y el cliente pesado.';tr = 'Bu işlevsellik yalnızca ince ve kalın istemci modunda kullanılabilir.';it = 'Questa funzionalità è disponibile solo in modalità client thin e thick.';de = 'Diese Funktionalität ist nur im Thin- und Thick-Client-Modus verfügbar.'"));
		Return;
	#EndIf
	
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject);
	EquipmentManagerClient.StartDriverFileSelection(Notification);
	
EndProcedure

#EndRegion
