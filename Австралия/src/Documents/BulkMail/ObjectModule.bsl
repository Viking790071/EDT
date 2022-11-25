#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SendingMethod = Enums.MessageType.SMS Then
		CheckedAttributes.Delete(CheckedAttributes.Find("UserAccount"));
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.RequestForQuotation") Then
		FillByRequestForQuotation(FillingData);
	EndIf;
	
EndProcedure

Procedure FillByRequestForQuotation(FillingData)
	
	BasisDocument = FillingData.Ref;
	Subject = FillingData.Subject;
	SendingMethod = Enums.MessageType.Email;
	
	FillByRequestForQuotation_FillRecipients(FillingData.Suppliers);
	FillByRequestForQuotation_FillContentHTML(FillingData.DescriptionOfRequirements);
	
EndProcedure

Procedure FillByRequestForQuotation_FillRecipients(Suppliers)
	
	For Each Supplier In Suppliers Do
		
		NewRow = Recipients.Add();
		NewRow.Contact = Supplier.ContactPerson;
		NewRow.HowToContact = Supplier.Email;
		NewRow.UseBcc = True;
		
	EndDo;
	
EndProcedure

Procedure FillByRequestForQuotation_FillContentHTML(DescriptionOfRequirements)
	
	FormattedDocument = New FormattedDocument;
	FormattedDocument.SetFormattedString(New FormattedString(DescriptionOfRequirements));
	FormattedDocument.GetHTML(ContentHTML, New Structure);
	
EndProcedure

#EndRegion

#EndIf