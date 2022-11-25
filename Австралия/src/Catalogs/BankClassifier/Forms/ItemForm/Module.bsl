
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Items.BankOperationsDiscontinuedPages.Visible = Object.OutOfBusiness Or Users.IsFullUser();
	Items.BankOperationsDiscontinuedPages.CurrentPage = ?(Users.IsFullUser(),
		Items.BankOperationsDiscontinuedCheckBoxPage, Items.BankOperationsDiscontinuedLabelPage);
		
	If Object.OutOfBusiness Then
		WindowOptionsKey = "OutOfBusiness";
		Items.BankOperationsDiscontinuedLabel.Title = BankManager.InvalidBankNote(Object.Ref);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		ModuleStandaloneMode.ObjectOnReadAtServer(CurrentObject, ThisObject.ReadOnly);
		
	EndIf;
	
EndProcedure

#EndRegion
