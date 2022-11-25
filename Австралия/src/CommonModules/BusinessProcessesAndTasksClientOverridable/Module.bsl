///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Called when opening an assignee selection form.
//  It overrides the standard selection form.
//
// Parameters:
//  PerformerItem   - FormItem - a form item where an assignee is selected. The form item is 
//                                      specified as the owner of the assignee selection form.
//  PerformerAttribute  - CatalogRef.Users - a previously selected assignee. Used to set the current 
//                                                         row in the assignee selection form.
//  SimpleRolesOnly    - Boolean - if True, only roles without addressing objects are used in the 
//                              selection.
//  WithoutExternalRoles      - Boolean - if True, only roles without the ExternalRole flag are used 
//                               in the selection.
//  StandardProcessing - Boolean - if False, displaying the standard assignee selection form is not required.
//
Procedure OnPerformerChoice(PerformerItem, PerformerAttribute, SimpleRolesOnly,
	NoExternalRoles, StandardProcessing) Export
	
EndProcedure

#EndRegion
