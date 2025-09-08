import SwiftUI

struct LicenseView: View {
    @State private var searchText = ""
    
    let licenses = [
        License(
            name: "Swift Tagged",
            version: "0.10.0",
            license: "MIT",
            url: "https://github.com/pointfreeco/swift-tagged"
        ),
        License(
            name: "Alamofire",
            version: "5.8.0",
            license: "MIT",
            url: "https://github.com/Alamofire/Alamofire"
        ),
        License(
            name: "Swift Async Algorithms",
            version: "1.0.0",
            license: "Apache 2.0",
            url: "https://github.com/apple/swift-async-algorithms"
        )
    ]
    
    var filteredLicenses: [License] {
        if searchText.isEmpty {
            return licenses
        } else {
            return licenses.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredLicenses) { license in
                NavigationLink {
                    LicenseDetailView(license: license)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(license.name)
                            .font(.headline)
                        
                        HStack {
                            Text("v\(license.version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(license.license)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "라이브러리 검색") // iOS 15+
    }
}

struct LicenseDetailView: View {
    let license: License
    @State private var isLoading = false
    @State private var licenseText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 라이브러리 정보
                VStack(alignment: .leading, spacing: 12) {
                    Label(license.name, systemImage: "shippingbox.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label("버전 \(license.version)", systemImage: "tag.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Label(license.license, systemImage: "doc.text.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: license.url)!) {
                        Label("GitHub 저장소", systemImage: "link")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 라이선스 텍스트
                VStack(alignment: .leading, spacing: 12) {
                    Text("라이선스 전문")
                        .font(.headline)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        Text(licenseText.isEmpty ? getMockLicenseText(for: license.license) : licenseText)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getMockLicenseText(for licenseType: String) -> String {
        switch licenseType {
        case "MIT":
            return """
            MIT License
            
            Copyright (c) 2024 \(license.name)
            
            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:
            
            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.
            
            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
            """
        case "Apache 2.0":
            return """
            Apache License
            Version 2.0, January 2004
            
            Licensed under the Apache License, Version 2.0 (the "License");
            you may not use this file except in compliance with the License.
            You may obtain a copy of the License at
            
                http://www.apache.org/licenses/LICENSE-2.0
            
            Unless required by applicable law or agreed to in writing, software
            distributed under the License is distributed on an "AS IS" BASIS,
            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
            See the License for the specific language governing permissions and
            limitations under the License.
            """
        default:
            return "라이선스 정보를 불러올 수 없습니다."
        }
    }
}

struct License: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let license: String
    let url: String
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}