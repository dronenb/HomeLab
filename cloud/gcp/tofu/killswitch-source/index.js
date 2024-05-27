// Original source: https://github.com/Asad-Leghari/GCP-Killswitch/tree/master

// Importing Required Libraries
import { google } from 'googleapis'
import { GoogleAuth } from 'google-auth-library'

// setting Global Variables
const projectID = process.env.PROJECT_ID
const projectName = `projects/${projectID}`
const billing = google.cloudbilling('v1').projects

// Diable Billing Function 
export async function killSwitch(pubsubevent) {

    // checking if project ID exists
    if(!projectID){
        return `provide project ID`
    }

    // getting the pubsub data and logic
    const data = JSON.parse( Buffer.from(pubsubevent.data, 'base64').toString() )

    if(data.costAmount <= data.budgetAmount) {
        return `Current Cost: ${data.costAmount}`
    }

    // setting global authentication credentials
    const client = new GoogleAuth({
        scopes: [
            'https://www.googleapis.com/auth/cloud-billing',
            'https://www.googleapis.com/auth/cloud-platform'
        ]
    })

    google.options({
        auth: client
    })

    // Checking Current Status Of Billing Account
    const billingEnabled = await checkBillingStatus(projectName)

    // removing billing Account from project
    if (billingEnabled) {
        return disableBilling(projectName);
    } else {
        return 'Billing is disabled';
    }
}

const checkBillingStatus = async(projectName) => {
    try {
        const response = await billing.getBillingInfo({
            name: projectName
        })
        return response.data.billing.billingEnabled
    } catch (error) {
        console.log('something went wrong')
        return true
    }
} 

const disableBilling = async (projectName) => {
    const response = await billing.updateBillingInfo({
        name: projectName,
        resource: {
            billingAccountName: ''
        }
    });
    return `${JSON.stringify(response.data)}`;
};
