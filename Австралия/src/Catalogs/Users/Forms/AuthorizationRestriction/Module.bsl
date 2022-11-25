#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.DueDate.ToolTip = Metadata.InformationRegisters.UsersInfo.Resources.ValidityPeriod.ToolTip;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) <> Type("ClientApplicationForm") Then
		Return;
	EndIf;
	
	InactivityPeriod = FormOwner.InactivityPeriodBeforeDenyingAuthorization;
	DueDate      = FormOwner.ValidityPeriod;
	
	If FormOwner.UnlimitedValidityPeriod Then
		PeriodType = "NoExpiration";
		CurrentItem = Items.PeriodTypeNoExpiration;
		
	ElsIf ValueIsFilled(DueDate) Then
		PeriodType = "TillDate";
		CurrentItem = Items.PeriodTypeTillDate;
		
	ElsIf ValueIsFilled(InactivityPeriod) Then
		PeriodType = "InactivityPeriod";
		CurrentItem = Items.PeriodTypeTimeout;
	Else
		PeriodType = "NotSpecified";
		CurrentItem = Items.PeriodTypeNotSpecified;
	EndIf;
	
	UpdateAvailability();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodTypeOnChange(Item)
	
	UpdateAvailability();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If PeriodType = "TillDate" Then
		If Not ValueIsFilled(DueDate) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Дата не указана.'; en = 'The date is not specified.'; pl = 'Nie wskazano daty.';es_ES = 'Fecha no indicada.';es_CO = 'Fecha no indicada.';tr = 'Tarih belirtilmedi.';it = 'La data non è stata definita.';de = 'Datum nicht angegeben.'"),, "DueDate");
			Return;
			
		ElsIf DueDate <= BegOfDay(CommonClient.SessionDate()) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Ограничение должно быть до завтра или более.'; en = 'The password expiration date must be tomorrow or later.'; pl = 'Data ważności hasła musi być jutro lub później.';es_ES = 'La restricción debe ser hasta mañana o más.';es_CO = 'La restricción debe ser hasta mañana o más.';tr = 'Kısıtlama yarına kadar veya daha fazla olmalıdır.';it = 'La data di scadenza della password deve essere domani o in seguito.';de = 'Das Passwort soll bis morgen oder später gelten.'"),, "DueDate");
			Return;
		EndIf;
	EndIf;
	
	FormOwner.InactivityPeriodBeforeDenyingAuthorization = InactivityPeriod;
	FormOwner.ValidityPeriod = DueDate;
	FormOwner.UnlimitedValidityPeriod = (PeriodType = "NoExpiration");
	
	Close();
	
EndProcedure

#EndRegion

#Region Private
	
&AtClient
Procedure UpdateAvailability()
	
	If PeriodType = "TillDate" Then
		Items.DueDate.AutoMarkIncomplete = True;
		Items.DueDate.Enabled = True;
	Else
		Items.DueDate.AutoMarkIncomplete = False;
		DueDate = Undefined;
		Items.DueDate.Enabled = False;
	EndIf;
	
	If PeriodType <> "InactivityPeriod" Then
		InactivityPeriod = 0;
	ElsIf InactivityPeriod = 0 Then
		InactivityPeriod = 60;
	EndIf;
	Items.InactivityPeriod.Enabled = PeriodType = "InactivityPeriod";
	
EndProcedure

#EndRegion
