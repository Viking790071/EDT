#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If FormType = "Form" Then
		StandardProcessing = False;
		SelectedForm = "CommonForm.SearchForm";
	EndIf;
	
EndProcedure

#EndRegion
