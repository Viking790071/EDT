///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

Function InteractionsContacts() Export

	Result = New Array();
	
	Contact = InteractionsClientServer.NewContactDetails();
	Contact.Type = Type("CatalogRef.Users");
	Contact.Name = "Users";
	Contact.Presentation = NStr("ru = 'Пользователи'; en = 'Users'; pl = 'Użytkownicy';es_ES = 'Usuarios';es_CO = 'Usuarios';tr = 'Kullanıcılar';it = 'Utenti';de = 'Benutzer'");
	Contact.InteractiveCreationPossibility = False;
	Contact.SearchByDomain = False;
	Result.Add(Contact);
	
	InteractionsClientServerOverridable.OnDeterminePossibleContacts(Result);
	Return New FixedArray(Result);

EndFunction

Function InteractionsSubjects() Export
	
	Subjects = New Array;
	InteractionsClientServerOverridable.OnDeterminePossibleSubjects(Subjects);
	Return New FixedArray(Subjects);
	
EndFunction

#EndRegion
