///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	CatalogAttributes = Metadata.Catalogs.ReportMailings.Attributes;
	Items.ServerAndDirectory.ToolTip      = CatalogAttributes.FTPDirectory.ToolTip;
	Items.Port.ToolTip                = CatalogAttributes.FTPPort.ToolTip;
	Items.Username.ToolTip               = CatalogAttributes.FTPUsername.ToolTip;
	Items.PassiveConnection.ToolTip = CatalogAttributes.FTPPassiveConnection.ToolTip;
	FillPropertyValues(ThisObject, Parameters, "Server, Directory, Port, Username, Password, PassiveConnection");
	If ThisObject.Server = "" Then
		ThisObject.Server = "server";
	EndIf;
	If ThisObject.Directory = "" Then
		ThisObject.Directory = "/directory/";
	EndIf;
	VisibleEnabled(ThisObject);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ServerAndDirectoryOnChange(Item)
	FillPropertyValues(ThisObject, ReportMailingClient.ParseFTPAddress(ServerAndDirectory), "Server, Directory");
	VisibleEnabled(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Fill(Command)
	If Server = "" Then
		FullAddress = NStr("ru = 'ftp://логин:пароль@сервер:порт/каталог'; en = 'ftp://username:password@server:port/directory'; pl = 'ftp://username:password@server:port/directory';es_ES = 'ftp://username:password@server:port/directory';es_CO = 'ftp://username:password@server:port/directory';tr = 'ftp://kullanıcıadı:şifre@sunucu:port/dizin';it = 'ftp://username:password@server:port/directory';de = 'ftp://username:password@server:port/directory'");
	Else
		If Username = "" Then
			FullAddress = "ftp://"+ Server +":"+ Format(Port, "NZ=21; NG=0") + Directory;
		Else
			FullAddress = "ftp://"+ Username +":"+ ?(ValueIsFilled(Password), PasswordHidden(), "") +"@"+ Server +":"+ Format(Port, "NZ=0; NG=0") + Directory;
		EndIf;
	EndIf;
	
	Handler = New NotifyDescription("FillCompletion", ThisObject);
	ShowInputString(Handler, FullAddress, NStr("ru = 'Введите полный ftp адрес'; en = 'Enter full ftp address'; pl = 'Wpisz cały adres ftp';es_ES = 'Introducir la dirección ftp completa';es_CO = 'Introducir la dirección ftp completa';tr = 'Tam ftp adresi girin';it = 'Inserire indirizzo ftp completo';de = 'Komplette ftp-Adresse angeben'"))
EndProcedure

&AtClient
Procedure OK(Command)
	ChoiceValue = New Structure("Server, Directory, Port, Username, Password, PassiveConnection");
	FillPropertyValues(ChoiceValue, ThisObject);
	NotifyChoice(ChoiceValue);
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure VisibleEnabled(Form, Changes = "")
	If Not StrEndsWith(Form.Directory, "/") Then
		Form.Directory = Form.Directory + "/";
	EndIf;
	Form.ServerAndDirectory = "ftp://"+ Form.Server + Form.Directory;
EndProcedure

&AtClient
Procedure FillCompletion(InputResult, AdditionalParameters) Export
	If InputResult <> Undefined Then
		PasswordBeforeInput = Password;
		FillPropertyValues(ThisObject, ReportMailingClient.ParseFTPAddress(InputResult));
		If Password = PasswordHidden() Then
			Password = PasswordBeforeInput;
		EndIf;
		VisibleEnabled(ThisObject);
	EndIf;
EndProcedure

&AtClient
Function PasswordHidden()
	Return "********";
EndFunction

#EndRegion
