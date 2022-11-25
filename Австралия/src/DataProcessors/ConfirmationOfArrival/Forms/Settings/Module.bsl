
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Document = Parameters.Document;
	Counterparty = Parameters.Counterparty;
	
	FillEmailsTable(Parameters.Emails);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure EmailsContactPersonOnChange(Item)
	
	CurrentData = Items.Emails.CurrentData;
	CurrentData.Email = GetContactPersonEmail(CurrentData.ContactPerson);
	
EndProcedure

&AtClient
Procedure EmailsEmailOnChange(Item)
	
	CurrentData = Items.Emails.CurrentData;
	CheckingResult = CommonClientServer.EmailsFromString(CurrentData.Email);
	
	ErrorDescription = CheckingResult[0].ErrorDescription;
	If Not IsBlankString(ErrorDescription) Then
		CommonClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	Close(New Structure("NewEmails", FillEmailsArray()));
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillEmailsTable(EmailsArray)
	
	For Each Email In EmailsArray Do
		FillPropertyValues(Emails.Add(), Email);
	EndDo;
	
EndProcedure

&AtClient
Function FillEmailsArray()
	
	EmailsArray = New Array;
	
	For Each EmailRow In Emails Do
		EmailsArray.Add(New Structure("ContactPerson, Email", EmailRow.ContactPerson, EmailRow.Email));
	EndDo;
	
	Return EmailsArray;
	
EndFunction

&AtServerNoContext
Function GetContactPersonEmail(ContactPerson)
	
	Info = DriveServer.InfoAboutContactPerson(ContactPerson);
	
	Return Info.Email;
	
EndFunction

#EndRegion
