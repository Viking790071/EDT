///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Specifies interaction subject types, for example, orders, vacancies and so on.
// It is used if at least one interaction subject is determined in the configuration.
//
// Parameters:
//  SubjectsTypes  - Array - interaction subjects (String), for example, "DocumentRef.CustomerOrder" 
//                            and so on.
//
Procedure OnDeterminePossibleSubjects(SubjectsTypes) Export
	
	SubjectsTypes.Add("DocumentRef.CreditNote");
	SubjectsTypes.Add("DocumentRef.GoodsIssue");
	SubjectsTypes.Add("DocumentRef.Quote");
	SubjectsTypes.Add("DocumentRef.SalesOrder");
	SubjectsTypes.Add("DocumentRef.SalesInvoice");
	SubjectsTypes.Add("DocumentRef.TaxInvoiceIssued");
	
EndProcedure

// Sets details of possible interaction contact types, for example: partners, contact persons and so on.
// It is used if at least one interaction contact type apart from the Users catalog is determined 
// int the configuration.
//
// Parameters:
//  ContactsTypes - Array - contains interaction contact type details (Structure) and their properties:
//     * Type - Type - a contact reference type.
//     * Name                               - String - a contact type name as it is defined in metadata.
//     * Presentation                     - String - a contact type presentation to be displayed to a user.
//     * Hierarchical                     - Boolean - indicates that this catalog is hierarchical.
//     * HasOwner                      - Boolean - indicates that the contact has an owner.
//     * OwnerName                      - String - a contact owner name as it is defined in metadata.
//     * SearchByDomain                    - Boolean - indicates that contacts of this type will be 
//                                                    picked by the domain map and not by the full email address.
//     * Link                             - String - describes a possible link of this contact with 
//                                                    some other contact when the current contact is an attribute of other contact.
//                                                    It is described with the "TableName.AttributeName" string.
//     * ContactPresentationAttributeName - String - a contact attribute name, from which a contact 
//                                                    presentation will be received. If it is not 
//                                                    specified, the standard Description attribute is used.
//     * InteractiveCreationPossibility - Boolean - indicates that a contact can be created 
//                                                    interactively from interaction documents.
//     * NewContactFormName - String - a full form name for a new contact creation.
//                                                    For example, "Catalog.Partners.Form.NewContactWizard".
//                                                    If it is not filled in, a default item form is opened.
//
Procedure OnDeterminePossibleContacts(ContactsTypes) Export
	
	Contact = InteractionsClientServer.NewContactDetails();
	Contact.Type = Type("CatalogRef.Counterparties");
	Contact.Name = "Counterparties";
	Contact.Presentation = NStr("en = 'Counterparties'; ru = 'Контрагенты';pl = 'Kontrahenci';es_ES = 'Contrapartes';es_CO = 'Contrapartes';tr = 'Cari hesaplar';it = 'Controparti';de = 'Geschäftspartner'");
	Contact.Hierarchical = True;
	ContactsTypes.Add(Contact);
	
	Contact = InteractionsClientServer.NewContactDetails();
	Contact.Type = Type("CatalogRef.ContactPersons");
	Contact.Name = "ContactPersons";
	Contact.Presentation = NStr("en = 'Contact persons'; ru = 'Контактные лица';pl = 'Osoby kontaktowe';es_ES = 'Personas de contacto';es_CO = 'Personas de contacto';tr = 'Kişiler';it = 'Persone di contatto';de = 'Ansprechpartner'");
	Contact.HasOwner = True;
	Contact.OwnerName = "Counterparties";
	ContactsTypes.Add(Contact);
	
	Contact = InteractionsClientServer.NewContactDetails();
	Contact.Type = Type("CatalogRef.Leads");
	Contact.Name = "Leads";
	Contact.Presentation = NStr("en = 'Leads'; ru = 'Лиды';pl = 'Leady';es_ES = 'Leads';es_CO = 'Leads';tr = 'Müşteri adayları';it = 'Potenziali Clienti';de = 'Leads'");
	ContactsTypes.Add(Contact);
	
EndProcedure

#EndRegion



