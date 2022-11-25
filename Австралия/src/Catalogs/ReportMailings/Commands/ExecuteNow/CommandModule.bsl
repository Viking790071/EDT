///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtClient
Procedure CommandProcessing(MailingArray, CommandExecuteParameters)
	If TypeOf(MailingArray) <> Type("Array") OR MailingArray.Count() = 0 Then
		Return;
	EndIf;
	
	Form = CommandExecuteParameters.Source;
	
	StartParameters = New Structure("MailingArray, Form, IsItemForm");
	StartParameters.MailingArray = MailingArray;
	StartParameters.Form = Form;
	StartParameters.IsItemForm = (Form.FormName = "Catalog.ReportMailings.Form.ItemForm");
	
	ReportMailingClient.ExecuteNow(StartParameters);
EndProcedure

#EndRegion
