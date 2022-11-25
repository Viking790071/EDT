///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// Adding fields on whose basis a business process presentation will be generated.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Fields                 - Array - fields used to generate a business process presentation.
//  StandardProcessing - Boolean - if False, the standard filling processing is skipped.
//                                  
//
Procedure BusinessProcessPresentationFieldsGetProcessing(ObjectManager, Fields, StandardProcessing) Export
	
	Fields.Add("Description");
	Fields.Add("Date");
	StandardProcessing = False;

EndProcedure

// ACC:547-off is called in the GetBusinessProcessPresentation event subscription.

// Use BusinessProcessesAndTasksClient.BusinessProcessPresentationGetProcessing for client calls
// Use BusinessProcessesAndTasksServer.BusinessProcessPresentationGetProcessing for server calls
// Processing for getting a business process presentation based on data fields.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Data               - Structure - the fields used to generate a business process presentation:
//  Presentation        - String - a business process presentation.
//  StandardProcessing - Boolean - if False, the standard filling processing is skipped.
//                                  
//
Procedure BusinessProcessPresentationGetProcessing(ObjectManager, Data, Presentation, StandardProcessing) Export
	
#If Server Or ThickClientOrdinaryApplication Or ThickClientManagedApplication Or ExternalConnection Then
	Date = Format(Data.Date, ?(GetFunctionalOption("UseDateAndTimeInTaskDeadlines"), "DLF=DT", "DLF=D"));
	Presentation = Metadata.FindByType(TypeOf(ObjectManager)).Presentation();
#Else	
	Date = Format(Data.Date, "DLF=D");
	Presentation = NStr("ru = 'Бизнес-процесс'; en = 'Business process'; pl = 'Proces biznesowy';es_ES = 'Proceso de negocio';es_CO = 'Proceso de negocio';tr = 'İş süreci';it = 'Processo di business';de = 'Geschäftsprozess'");
#EndIf
	
	BusinessProcessPresentationGet(ObjectManager, Data, Date, Presentation, StandardProcessing);
	
EndProcedure

// ACC:547-on is called in the GetBusinessProcessPresentation event subscription.

#EndRegion

#Region Private

// Data processor of receiving a business process presentation based on data fields.
//
// Parameters:
//  ObjectManager      - BusinessProcessManager - a business process manager.
//  Data               - Structure - the fields used to generate a business process presentation, where:
//   * Description      - String - a business process description.
//  Date                 - Date   - a business process creation date.
//  Presentation        - String - a business process presentation.
//  StandardProcessing - Boolean - if False, the standard filling processing is skipped.
//                                  
//
Procedure BusinessProcessPresentationGet(ObjectManager, Data, Date, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	PresentationTemplate  = NStr("ru = '%1 от %2 (%3)'; en = '%1 dated %2 (%3)'; pl = '%1 z dn. %2 (%3)';es_ES = '%1 fechado %2 (%3)';es_CO = '%1 fechado %2 (%3)';tr = '%1 tarih %2 (%3)';it = '#%1, con data %2 (%3)';de = '%1 datiert %2 (%3)'");
	Description         = ?(IsBlankString(Data.Description), NStr("ru = 'Без описания'; en = 'No description'; pl = 'Brak opisu';es_ES = 'Sin descripción';es_CO = 'Sin descripción';tr = 'Açıklama yok';it = 'Senza descrizione';de = 'Keine Beschreibung'"), Data.Description);
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(PresentationTemplate, Description, Date, Presentation);
	
EndProcedure

#EndRegion